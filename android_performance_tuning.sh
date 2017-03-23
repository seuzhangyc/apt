#!/bin/bash

# debug="enable"

wait_until()
{
	end_time=$1

	while [ `date +%s` -lt $end_time ]
	do
		sleep 0.1
	done
}

get_packages()
{
	local i=0

	for p in `adb $adb_on_device shell "pm list package -e" | tr -d "\r" | sed 's/package://g'`
	do
		# echo $p
		if [[ -n `grep -w "$p$" $pkgs_withoutui_file` ]]; then
			# echo "	remove $p"
			continue
		fi

		let i=i+1

		# echo "$p" >> $result_dir"/pkgs_withui.txt"
		pkgs_name[i]="$p"  # [1] <=> com.android.xx
		pkgs_name2index["$p"]=$i # [com.android.xx] <=> i
	done

	echo "Find $i packages(with UI)"
}

get_log()
{
	local when=$1
	local p=$2

	prefix="\n==> `date "+%F@%H:%M:%S"`, $when launch package: [${pkgs_name2index["$p"]}] $p\n"

	# 0. add tag
	echo -e "$prefix" >> $kernel_log_file
	echo -e "$prefix" >> $lmk_log_file
	echo -e "$prefix" >> $meminfo_file
	echo -e "$prefix" >> $vmstat_file
	echo -e "$prefix" >> $logcat_file
	echo -e "$prefix" >> $ams_file
	echo -e "$prefix" >> $logcat_events_file
	echo -e "$prefix" >> $cpusched_file
	echo -e "$prefix" >> $dumpsys_meminfo_file

	# 1. kernel log
	adb $adb_on_device shell "dmesg -c" 2>/dev/null| sed '/auditd/d' | tee -a $kernel_log_file | grep -A3 -E "lowmemorykiller.*Killing" >> $lmk_log_file

	# 2. meminfo
	adb $adb_on_device shell "cat /proc/meminfo" >> $meminfo_file

	# 3. get vmstat
	adb $adb_on_device shell "cat /proc/vmstat" >> $vmstat_file

	# 4. logcat

	adb $adb_on_device logcat -d -b main -b system $crash_str | tee -a $logcat_file | grep -e \
		"ActivityManager:" -e " am_" -e " Timeline" -e " wm_ " -e " art" -e " AndroidRuntime" -e " dex2oat"\
		-e "WhetstoneService" -e "WtProcessController" -e "WtProcessStrategy" -e "WtMemStrategy" -e "WhetstonePackageState" -e "PowerKeeperPolicy" \
		-e "octvm" -e "octvm_drv" -e "octvm_whetstone" -e "MemController" -e "MemCheckStateMachine" \
		-e "AutoStartManagerService" \
		-e " RenderThread"  -e " NotifierManager"  -e " ANDR-PERF-MPCTL" -e " BoostFramework" >> $ams_file

	adb $adb_on_device logcat -d -b events | sed '/auditd/d' >> $logcat_events_file

	 # clear buffer
	adb $adb_on_device logcat -c -b main -b system $crash_str
	adb $adb_on_device logcat -c -b events >>$log_file

	# 5. cpu top
	adb $adb_on_device shell "top -m 10 -t -n 1 -d 2" | sed '1,3d'>> $cpusched_file # show top 10 threads

	case $when in
		"before")
			;;
		"on")
			;;
		"after")
			adb $adb_on_device shell dumpsys meminfo >> $dumpsys_meminfo_file
			;;
	esac
}

calc_avg()
{
	# ignore 0 value
	avg=`cat $1 | awk 'BEGIN{sum=0; cnt=0} {sum+=$1; if($1!=0) cnt++;} END{if(cnt==0)printf "%d",0; else printf "%d",sum/cnt}'`
	echo "$avg"
}

splite_file()
{
	local input_file=$1
	local output_dir=$2

	# /A/B/c.txt => c.txt
	#local input_file_name=`echo "$input_file" | sed 's/.*\/\(.*$\)/\1/g'`
	local base_name=`basename $input_file`

	# csplit meminfo.txt file to meminfo_xxx.txt
	csplit $input_file /^==\>.*/ -n3 -s {*} -f $output_dir/$base_name -b "_split_%03d" ; rm $output_dir/${base_name}_split_000 ;

	# splited_files is global var
	splited_files=`find $output_dir -name ${base_name}_* | sort`
}

extract_meminfo()
{
	local loop=$1

	splite_file $meminfo_file $tmp_dir

	# iterate each split file
	for file in $splited_files
	do
		# echo $file
		local tmp=(`sed -n 's/==>.*, \(.*\) launch package: \[.*\] \(.*\)/\1 \2/gp' $file | tr -d '\r'`) # get when and pkg
		local when=${tmp[0]}
		local p=${tmp[1]}
		local p_index=${pkgs_name2index["$p"]}
		local i=$(((p_index-1)*3+when_offset[$when]))
		# echo "${tmp[@]} => $when,$p,$p_index,$i"
		declare -A m

		if [[ -z $p_index ]]; then
			echo "why does $p exist in $meminfo_file ??"
		fi

		# read each line
		while read line
		do
			# echo "line:" $line
			if [[ -z `echo "$line" | tr -d '\r' | sed -n '/kB$/p'` ]]; then
				continue
			fi

			key=`echo $line | sed 's/\(.*\):.*/\1/g'`
			val=`echo $line | awk '{printf "%d",$2/1024}'`
			# val=`echo $line | awk '{printf "%.2f",$2}'`
			# echo $key,$val
			m["$key"]=$val

			case "$key" in
				"MemFree")
					mem_free[i]=$val
					;;
				"SwapCached")
					mem_swapcache[i]=$val
					;;
				"Active(anon)")
					mem_activeanon[i]=$val
					;;
				"Inactive(anon)")
					mem_inactiveanon[i]=$val
					;;
				"Active(file)")
					mem_activefile[i]=$val
					;;
				"Inactive(file)")
					mem_inactivefile[i]=$val
					;;
				"SwapTotal")
					mem_swaptotal=$val
					;;
				"SwapFree")
					mem_swapfree[i]=$val
					;;
				"AnonPages")
					mem_anonpages[i]=$val
					;;
				"Mapped")
					mem_mapped[i]=$val
					;;
				"Shmem")
					mem_shmem[i]=$val
					;;
				"Slab")
					mem_slab[i]=$val
					;;
			esac

		done < $file

		mem_filecache[i]=`echo "scale=2; (${mem_activefile[i]}+${mem_inactivefile[i]}-${mem_swapcache[i]}-${mem_shmem[i]})/1" | bc`
		mem_anon[i]=`echo "scale=2; (${mem_activeanon[i]}+${mem_inactiveanon[i]})/1" | bc`
		mem_swapused[i]=`echo "scale=2; (${mem_swaptotal}-${mem_swapfree[i]})/1" | bc`

	done

	# for manually analyse
	echo ${mem_free[@]} | tr ' ' '\n'> $extract_mem_dir/mem_free.txt
	echo ${mem_swapcache[@]} | tr ' ' '\n'> $extract_mem_dir/mem_swapcache.txt
	echo ${mem_activeanon[@]} | tr ' ' '\n'> $extract_mem_dir/mem_activeanon.txt
	echo ${mem_inactiveanon[@]} | tr ' ' '\n'> $extract_mem_dir/mem_inactiveanon.txt
	echo ${mem_activefile[@]} | tr ' ' '\n'> $extract_mem_dir/mem_activefile.txt
	echo ${mem_inactivefile[@]} | tr ' ' '\n'> $extract_mem_dir/mem_inactivefile.txt
	echo ${mem_swaptotal} | tr ' ' '\n'> $extract_mem_dir/mem_swaptotal.txt
	echo ${mem_swapfree[@]} | tr ' ' '\n'> $extract_mem_dir/mem_swapfree.txt
	echo ${mem_anonpages[@]} | tr ' ' '\n'> $extract_mem_dir/mem_anonpages.txt
	echo ${mem_mapped[@]} | tr ' ' '\n'> $extract_mem_dir/mem_mapped.txt
	echo ${mem_shmem[@]} | tr ' ' '\n'> $extract_mem_dir/mem_shmem.txt
	echo ${mem_slab[@]} | tr ' ' '\n'> $extract_mem_dir/mem_slab.txt

	# calculated

	echo ${mem_filecache[@]} | tr ' ' '\n'> $extract_mem_dir/mem_filecache.txt
	echo ${mem_anon[@]} | tr ' ' '\n'> $extract_mem_dir/mem_anon.txt
	echo ${mem_swapused[@]} | tr ' ' '\n'> $extract_mem_dir/mem_swapused.txt
}

extract_lmk()
{
	local loop=$1

	splite_file $lmk_log_file $tmp_dir

	# iterate each split file
	for file in $splited_files
	do
		# echo $file
		local tmp=(`sed -n 's/==>.*, \(.*\) launch package: \[.*\] \(.*\)/\1 \2/gp' $file | tr -d '\r'`)
		local when=${tmp[0]}
		local p=${tmp[1]}
		local p_index=${pkgs_name2index["$p"]}
		local i=$(((p_index-1)*3+when_offset[$when]))
		# echo "${tmp[@]} => $when,$p,$index"

		# get lmk count
		local cnt=`cat $file | grep -E "lowmemorykiller.*Killing" | wc -l`
		cnt=$((cnt*10)) # x10, to see it clearly in csv file

		# get mem freed by lmk
		local mem_freed=`cat $file | sed -n 's/.*to free \([0-9]*\)kB .*/\1/gp' | awk 'BEGIN{sum=0}{sum+=$1/1024} END{printf "%d",sum}'`

		# find min adj killed
		minadjkilled=`cat $file | grep -E "lowmemorykiller.*Killing" | sed 's/.*, adj \(.*\),/\1/g' | sort -n | sed -n '1p' | tr -d '\r'`
		if [ -z $minadjkilled ]; then
			minadjkilled=0
		fi

		lmk_cnt[i]=$cnt
		lmk_mem_freed[i]=$mem_freed
		lmk_minadjkilled[i]=$minadjkilled
	done

	echo ${lmk_cnt[@]} | tr ' ' '\n' > $extract_lmk_dir/lmk_cnt.txt
	echo ${lmk_memfreed[@]} | tr ' ' '\n' > $extract_lmk_dir/lmk_memfreed.txt
	echo ${lmk_minadjkilled[@]} | tr ' ' '\n' > $extract_lmk_dir/lmk_minadjkilled.txt
}

extract_app_launch_time()
{
	local loop=$1

	grep -e "Activity_launch_request" -e "Activity_windows_visible" $ams_file > $timeline_file

	# set pkgs_launch_time to all 0
	for i in `eval echo {1..${#pkgs_name_launched[@]}}`
	do
		pkgs_launch_time[$i]=0
	done

	local request_time=""
	local visiable_time=""

	while read line
	do
		if [[ -n `echo "$line" | sed -n '/Activity_launch_request/p'` ]]; then
			request_time=`echo "$line" | sed 's/.*time:\([0-9]*\).*/\1/g'`
		fi

		if [[ -n `echo "$line" | sed -n '/Activity_windows_visible/p'` ]]; then
			local p=`echo "$line" | sed 's/.* \(.*\)\/.*/\1/g'`
			local index=${pkgs_name2index["$p"]}

			# if pkg is the one we want to test, and has not yet get launch time of it
			if [[ -n "$request_time" ]] && [[ -n $index ]] && [[ ${pkgs_launch_time[$index]} -eq 0 ]]; then
				visiable_time=`echo "$line" | sed 's/.*time:\([0-9]*\).*/\1/g'`

				echo "extract_app_launch_time(): [$index] $p: $visiable_time-$request_time = $(($visiable_time-$request_time))" >> $tmp_dir/debug.launchtime.txt
				pkgs_launch_time[$index]=`echo "$visiable_time-$request_time" | bc`
			fi

			request_time=""
			visiable_time=""
		fi
	done < $timeline_file

	echo ${pkgs_launch_time[@]} | tr ' ' '\n' > $extract_dir/pkgs_launch_time.txt
}

extract_ams()
{
	local loop=$1

	splite_file $ams_file $tmp_dir

	# iterate each split file
	for file in $splited_files
	do
		# echo $file
		local tmp=(`sed -n 's/==>.*, \(.*\) launch package: \[.*\] \(.*\)/\1 \2/gp' $file | tr -d '\r'`) # get when and pkg
		local when=${tmp[0]}
		local p=${tmp[1]}
		local p_index=${pkgs_name2index["$p"]}
		local i=$(((p_index-1)*3+when_offset[$when]))
		# echo "${tmp[@]} => $when,$p,$p_index,$i"

		# get ams_start_proc count
		start_proc_cnt=`cat $file | grep -E "ActivityManager: Start proc" | wc -l`
		[[ -z $start_proc_cnt ]] && start_proc_cnt=0
		start_proc_cnt=$((start_proc_cnt*10)) # x10, to see it clearly in csv file

		# get kernel kill count
		has_died_cnt=`cat $file | grep -E "ActivityManager:.*has died" | wc -l`
		[[ -z $has_died_cnt ]] && has_died_cnt=0
		has_died_cnt=$((has_died_cnt*10)) # x10, to see it clearly in csv file

		ams_startproc[i]=$start_proc_cnt
		ams_hasdied[i]=$has_died_cnt

	done

	echo ${ams_startproc[@]} | tr ' ' '\n'> $extract_ams_dir/ams_startproc.txt
	echo ${ams_hasdied[@]} | tr ' ' '\n'> $extract_ams_dir/ams_hasdied.txt
}


extract_events()
{
	local loop=$1

	splite_file $logcat_events_file $tmp_dir

	# iterate each split file
	for file in $splited_files
	do
		# echo $file
		local tmp=(`sed -n 's/==>.*, \(.*\) launch package: \[.*\] \(.*\)/\1 \2/gp' $file | tr -d '\r'`) # get when and pkg
		local when=${tmp[0]}
		local p=${tmp[1]}
		local p_index=${pkgs_name2index["$p"]}
		local i=$(((p_index-1)*3+when_offset[$when]))
		# echo "${tmp[@]} => $when,$p,$p_index,$i"

		#
		# kill
		#

		# get am_kill
		am_kill_cnt=`cat $file | grep -E "am_kill" | wc -l`
		am_kill_cnt=$((am_kill_cnt*10))

		# get ams empty kill
		empty_kill=`cat $file | grep -E "am_kill.*empty" | wc -l`
		empty_kill=$((empty_kill*10))

		# get whetstone kill
		whetstone_kill_cnt=`cat $file | grep -E "am_kill.*whetstone" | wc -l`
		whetstone_kill_cnt=$((whetstone_kill_cnt*10))

		# get Security Center kill
		securitycenter_kill_cnt=`cat $file | grep -E "am_kill.*SecurityCenter" | wc -l`
		securitycenter_kill_cnt=$((securitycenter_kill_cnt*10))

		# get forcestop kill
		forcestop_kill_cnt=`cat $file | grep -E "am_kill.*stop.*from pid" | wc -l`
		forcestop_kill_cnt=$((forcestop_kill_cnt*10))

		ams_kill[i]=$am_kill_cnt
		ams_empty_kill[i]=$empty_kill
		ams_whetstone_kill[i]=$whetstone_kill_cnt
		ams_securitycenter_kill[i]=$securitycenter_kill_cnt
		ams_forcestop_kill[i]=$forcestop_kill_cnt

	done

	echo ${ams_kill[@]} | tr ' ' '\n'> $extract_ams_dir/ams_kill.txt
	echo ${ams_empty_kill[@]} | tr ' ' '\n'> $extract_ams_dir/ams_empty_kill.txt
	echo ${ams_whetstone_kill[@]} | tr ' ' '\n'> $extract_ams_dir/ams_whetstone_kill.txt
	echo ${ams_securitycenter_kill[@]} | tr ' ' '\n'> $extract_ams_dir/ams_securitycenter_kill.txt
	echo ${ams_forcestop_kill[@]} | tr ' ' '\n'> $extract_ams_dir/ams_forcestop_kill.txt
}


# anaylise each loop log
analyse_log()
{
	local loop=$1

	#
	# define VARs
	#

	# meminfo
	mem_total=0

	mem_free=()
	mem_available=()
	mem_buffers=()
	mem_cached=()
	mem_swapcache=()
	mem_active=()
	mem_inactive=()
	mem_activeanon=()
	mem_inactiveanon=()
	mem_activefile=()
	mem_inactivefile=()
	mem_unevictable=()
	mem_mlocked=()
	mem_swaptotal=0
	mem_swapfree=()
	mem_dirty=()
	mem_writeback=()
	mem_anonpages=()
	mem_mapped=()
	mem_shmem=()
	mem_slab=()
	mem_sreclaimable=()
	mem_sunreclaim=()
	mem_kernelstack=()
	mem_pagetables=()
	mem_commitlimit=()
	mem_commitlimitas=()
	mem_vmalloctotal=0
	mem_vmallocused=()
	mem_vmallocchunk=()
	mem_filecache=() # calculated
	mem_anon=() # calculated
	mem_swapused=() # calculated

	# vmstat

	mem_avg=()

	# lmk
	lmk_cnt=()
	lmk_memfreed=()
	lmk_minadjkilled=()

	lmk_avg=()

	# ams
	ams_startproc=()
	ams_hasdied=()

	ams_kill=()
	ams_empty_kill=()
	ams_whetstone_kill=()
	ams_securitycenter_kill=()
	ams_forcestop_kill=()

	ams_avg=()

	pkgs_launch_time=()

	echo "analyse loop $loop"

	#
	# 1. extract data
	#

	# 1.1 extract meminfo
	extract_meminfo $loop

	# 1.2 extract lmk info
	extract_lmk $loop

	# 1.3 extract ams info
	extract_ams $loop

	# 1.4 extract events info
	extract_events $loop

	# 1.4 extract app launch time
	extract_app_launch_time $loop

	#
	# 2. analyse data
	#

	echo ${pkgs_name_launched[@]} | tr ' ' '\n' >> $extract_dir/pkgs_name_launched.txt
	paste -d " " $extract_dir/pkgs_name_launched.txt $extract_dir/pkgs_name_launched.txt $extract_dir/pkgs_name_launched.txt \
			| tr ' ' '\n' > $extract_dir/pkgs_name_launched_3x.txt

	# 2.1 memory loop
	local mem_loop_file=$loop_dir/memory-$loop.csv

	echo -e "p_index \
			pkg \
			mem_free \
			mem_filecache \
			mem_anon \
			mem_anonpages \
			mem_mapped \
			slab \
			swapused \
			swaptotal \
			lmk_cnt \
			lmk_minfree5 \
			ams_startproc \
			ams_hasdied \
			ams_kill \
			ams_empty_kill \
			ams_whetstone_kill \
			ams_securitycenter_kill \
			ams_forcestop_kill \
			launch_time"\
			>> $mem_loop_file

	for i in `eval echo {1..$((${#pkgs_name_launched[@]}*3))}` # why need eval?
	do
		p_index=$(((i+2)/3))
		p=${pkgs_name_launched[p_index]}

		echo -e "$p_index\
				$p \
				${mem_free[i]} \
				${mem_filecache[i]} \
				${mem_anon[i]} \
				${mem_anonpages[i]} \
				${mem_mapped[i]} \
				${mem_slab[i]} \
				${mem_swapused[i]} \
				${mem_swaptotal} \
				${lmk_cnt[i]} \
				${lmk_minfree_ajusted_M[5]} \
				${ams_startproc[i]} \
				${ams_hasdied[i]} \
				${ams_kill[i]} \
				${ams_empty_kill[i]} \
				${ams_whetstone_kill[i]} \
				${ams_securitycenter_kill[i]} \
				${ams_forcestop_kill[i]} \
				${pkgs_launch_time[p_index]}"\
				>> $mem_loop_file
	done

	# 2.2 mem report: average data of each loop
	if [ ! -e $report_mem_file ]; then
		echo -e "loop \
				mem_free \
				mem_filecache \
				mem_anon \
				swapused \
				lmk_cnt \
				ams_kill \
				pkgs_launch_time"\
				>> $report_mem_file
	fi

	echo "$loop \
		`calc_avg $extract_mem_dir/mem_free.txt` \
		`calc_avg $extract_mem_dir/mem_filecache.txt` \
		`calc_avg $extract_mem_dir/mem_anon.txt` \
		`calc_avg $extract_mem_dir/mem_swapused.txt` \
		`calc_avg $extract_lmk_dir/lmk_cnt.txt` \
		`calc_avg $extract_ams_dir/ams_kill.txt` \
		`calc_avg $extract_dir/pkgs_launch_time.txt` \
		" >> $report_mem_file

	# 2.3 app launch time
	if [ ! -e $report_pkgs_launch_time_file ]; then
		echo "loop ${pkgs_name_launched[@]}" >> $report_pkgs_launch_time_file
	fi
	echo "$loop ${pkgs_launch_time[@]}" >> $report_pkgs_launch_time_file
}

run_action_before_launch_app()
{
	if [ -e $action_before_launch_app_file ]; then
		sh $action_before_launch_app_file $*
	fi
}

run_action_after_launch_app()
{
	if [ -e $action_after_launch_app_file ]; then
		sh $action_after_launch_app_file $*
	fi
}

run_action_before_loop()
{
	if [ -e $action_before_loop_file ]; then
		echo "  run action before loop $loop"

		sh $action_before_loop_file $*
	fi
}

run_action_before_test()
{
	if [ -e $action_before_test_file ]; then
		echo "run action before test"

		sh $action_before_test_file $*
	fi
}

prepare_loop()
{
	local loop=$1

	echo "preparing loop $loop"

	run_action_before_loop $result_dir $loop

	# save and clear kernel/fw log
	echo "  save and clear kernel/framework log"
	adb $adb_on_device shell dmesg -c 2>>$log_file > $log_dir/kmesg_beforetest.txt
	adb $adb_on_device logcat -d -b main -b system $crash_str > $log_dir/logcat_beforetest.txt
	adb $adb_on_device logcat -d -b events > $log_dir/logcat_events_beforetest.txt

	adb $adb_on_device logcat -c -b main -b system $crash_str
	adb $adb_on_device logcat -c -b events >>$log_file
}



#
# 1. iterate each app(launch it) and get log
# 2. analyse loop log
# 3. goto 1, until loop end
#
launch_apps()
{
	local loop=$1

	#
	# define some DIRs
	#

	# dir for this loop
	local loop_dir=$result_dir/$loop

	# log dir
	local log_dir=$loop_dir/1-log
	mkdir -p $log_dir

	# tmp dir
	local tmp_dir=$loop_dir/.tmp
	mkdir -p $tmp_dir

	# extract dir
	local extract_dir=$loop_dir/2-extract

	local extract_mem_dir=$extract_dir/mem
	mkdir -p $extract_mem_dir

	local extract_lmk_dir=$extract_dir/lmk
	mkdir -p $extract_lmk_dir

	local extract_ams_dir=$extract_dir/ams
	mkdir -p $extract_ams_dir

	# systrace dir
	local systrace_dir=$loop_dir/1-systrace
	mkdir -p $systrace_dir

	#
	# define some FILEs
	#

	# log files
	kernel_log_file=$log_dir/kmesg.txt
	lmk_log_file=$log_dir/lmk.txt
	meminfo_file=$log_dir/meminfo.txt
	vmstat_file=$log_dir/vmstat.txt
	cpusched_file=$log_dir/cpusched.txt

	logcat_file=$log_dir/logcat.txt
	logcat_events_file=$log_dir/logcat_events.txt
	ams_file=$log_dir/ams.txt
	timeline_file=$log_dir/timeline.txt
	dumpsys_meminfo_file=$log_dir/dumpsys_meminfo.txt

	#
	# define some VARs
	#
	declare -A when_offset
	when_offset=(["before"]=1 ["on"]=2 ["after"]=3)

	echo "-----------------"
	echo "loop $loop start at: "`date "+%F@%H:%M:%S"`
	echo "-----------------"

	# prepare before loop
	prepare_loop $loop

	local i=0
	local t=0

	echo "launch app loop $loop"
	for i in `eval echo {1..${#pkgs_name[@]}}`
	do
		p=${pkgs_name[i]}
		pkgs_name_launched[i]=$p

		#
		# 1. launch home
		#

		# adb $adb_on_device shell "input keyevent 3"
		t=`date +%s`
		adb $adb_on_device shell "monkey -p com.miui.home 1" > /dev/null

		wait_until $((t+${args["time_from_launch_home"]}))

		#
		# 2. launch app and get log
		#
		echo "  Launch $i/${#pkgs_name[@]} $p"

		# 2.1 get log before launching app
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 1 => `date +%s` before get_log"
		get_log "before" $p
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 2 => `date +%s` after get_log"

		# 2.2 launch app

		if [ ${args["get_systrace"]} -eq 1 ]; then
			python ~/Android/Sdk/platform-tools/systrace/systrace.py gfx input view webview wm am app dalvik sched \
				freq idle load memreclaim -t 5 -o $systrace_dir/$loop-$i-$sample-$p.html >/dev/null 2>/dev/null &
		fi

		run_action_before_launch_app $result_dir $loop $i $p

		t=`date +%s`
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 3 => $t base"
		result=`adb $adb_on_device shell "monkey -p $p 1"`
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 4 => `date +%s` after monkey"

		# check result
		if [[ -n `echo $result | grep "No activities found to run, monkey aborted"` ]]; then
			# fail to launch app
			echo "	[FAIL] launch package <$p>"

			# append to $pkgs_withoutui_file
			echo "--> $p" >> $pkgs_withoutui_file
		fi

		# 2.3 get log when app is launching
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 5 => `date +%s`"
		wait_until $((t+${args["time1_from_launch_app"]}))
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 6 => `date +%s` before get_log"
		get_log "on" $p;
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 7 => `date +%s` after get_log"

		if [ ${args["get_systrace"]} -eq 1 ]; then
			wait %1 # wait until systrace finished
		fi
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 8 => `date +%s` systrace finished"

		# 2.4 get log after app launched
		wait_until $((t+${args["time2_from_launch_app"]}))
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 9 => `date +%s` before get_log"
		get_log "after" $p;
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 10 => `date +%s` after get_log"

		run_action_after_launch_app $result_dir $loop $i $p

		wait_until $((t+${args["time3_from_launch_app"]}))
		[ ${args["show_timestamp"]} -eq 1 ] && echo "$p: 11 => `date +%s` end"

		# check whether exit
		if [ $i -ge ${args["test_pkgs"]} ]; then
			break
		fi

	done

	analyse_log $loop

	echo "-----------------"
	echo "loop $loop end at: "`date "+%F@%H:%M:%S"`
	echo "-----------------"
}

get_system_info()
{
	# LMK
	echo -e "------ LMK INFO ------" >> $report_file
	lmk_adj=(`adb $adb_on_device shell "cat /sys/module/lowmemorykiller/parameters/adj" | tr ',' ' '`)
	lmk_minfree=(`adb $adb_on_device shell "cat /sys/module/lowmemorykiller/parameters/minfree" | tr ',' ' '`)
	lmk_minfree_M=(`echo ${lmk_minfree[@]} | awk '{for(i=1;i<=NF;i++) printf "%d ",$i*4096/1024/1024}'`) # xx MB
	lmk_minfree_ajusted_M=(`echo ${lmk_minfree_M[@]} | awk '{for(i=1;i<=NF;i++) printf "%d ",$i*1.25}'`) # *1.25

	echo ${lmk_adj[@]} >> $report_file
	echo ${lmk_minfree[@]} >> $report_file
	echo ${lmk_minfree_M[@]} >> $report_file
	echo ${lmk_minfree_ajusted_M[@]} >> $report_file

	# screen size
	# adb $adb_on_device shell dumpsys window displays |head -n 3

}

get_brief_info()
{
	echo -e "========================================================" >> $report_file
	echo -e "    android performance tunning" >> $report_file
	echo -e "    start at `date "+%F %T"`"　>> $report_file
	echo -e "========================================================\n" >> $report_file

	get_system_info

	echo -e "\n------ profile ------\n" >> $report_file
	cat $profile_file >> $report_file
}

push_file()
{
	local host_file=$1
	local target_file=$2

	if [[ -n `adb $adb_on_device shell ls $target_file | grep "No such file or directory"` ]]; then
		adb $adb_on_device remount
		adb $adb_on_device push $host_file $target_file
		adb $adb_on_device shell chmod +x $target_file
	fi
}

install_tools()
{
	echo "install tools"

	adb $adb_on_device remount > /dev/null

	#if [ ! -e $pkgs_withoutui_file ]; then
	#	wget https://raw.githubusercontent.com/yzkqfll/apt/master/pkgs_withoutui.txt -O $pkgs_withoutui_file > /dev/null
	#fi

	#if [ ! -e $tools_dir/my_dd ]; then
	#	wget https://raw.githubusercontent.com/yzkqfll/apt/master/tools/my_fio -O $tools_dir/my_dd > /dev/null
	#fi
	echo "  install my_dd"
	push_file $tools_dir/my_dd /system/bin/my_dd >> $log_file

	#if [ ! -e $tools_dir/my_fio ]; then
	#	wget https://raw.githubusercontent.com/yzkqfll/apt/master/tools/my_fio -O $tools_dir/my_fio > /dev/null
	#fi
	echo "  install my_fio"
	push_file $tools_dir/my_fio /system/bin/my_fio >> $log_file
}

parse_profile()
{
	local f=$1

	mkdir -p /tmp/$$
	splite_file $f /tmp/$$

	# iterate each split file
	for file in $splited_files
	do
		#echo -e "file: $file"

		type=`sed -n '/^==>/s/==> \(.*\)/\1/gp' $file`
		sed -i '/^==>/d' $file
		#echo "type = $type"

		if [[ "$type" == "__global__" ]]; then
			while read line
			do
				if [[ -z $line ]] || [[ -n `echo "$line" | sed -n '/^#/p'` ]]; then
					continue
				fi

				key=`echo $line | sed 's/\(.*\)=.*/\1/g'`
				val=`echo $line | sed 's/\(.*\)=\(.*\)/\2/g'`
				# echo $key,$val
				args["$key"]=$val
			done < $file

		else
			cat util.sh $file > /tmp/apt-$$.sh
			sed -i 's/$adb_on_device/ /g' /tmp/apt-$$.sh
			sed -i "s/adb /adb $adb_on_device /g" /tmp/apt-$$.sh

			case "$type" in
				__action_before_test__)
					cat /tmp/apt-$$.sh > $action_before_test_file
					chmod +x $action_before_test_file
					;;
				__action_before_loop__)
					cat /tmp/apt-$$.sh > $action_before_loop_file
					chmod +x $action_before_loop_file
					;;
				__action_before_launch_app__)
					cat /tmp/apt-$$.sh > $action_before_launch_app_file
					chmod +x $action_before_launch_app_file
					;;
				__action_after_launch_app__)
					cat /tmp/apt-$$.sh > $action_after_launch_app_file
					chmod +x $action_after_launch_app_file
					;;
				*)
					echo "Bad type $opt, please check your profile $f"
					exit
					;;
			esac
		fi
	done

	rm -fr /tmp/$$

	#
	# check args
	#
	if [[ -z "${args["show_timestamp"]}" ]]; then
		args["show_timestamp"]=0
	fi

	if [[ -z "${args["time_from_launch_home"]}" ]]; then
		args["time_from_launch_home"]=5
	fi

	if [[ -z "${args["time1_from_launch_app"]}" ]]; then
		args["time1_from_launch_app"]=3
	fi

	if [[ -z "${args["time2_from_launch_app"]}" ]]; then
		args["time2_from_launch_app"]=10
	fi

	if [[ -z "${args["time3_from_launch_app"]}" ]]; then
		args["time3_from_launch_app"]=15
	fi

	if [[ -z "${args["get_systrace"]}" ]]; then
		args["get_systrace"]=0
	fi

	if [[ -z "${args["test_pkgs"]}" ]]; then
		args["test_pkgs"]=50
	fi

	if [[ -z "${args["test_loops"]}" ]]; then
		args["test_loops"]=100
	fi

	if [[ -z "${args["test_loops"]}" ]]; then
		args["test_loops"]=100
	fi

	# show args
	echo "=========================================="
	for key in ${!args[@]}
	do
		echo -e "  $key : ${args["$key"]}"
	done
	echo "=========================================="

	# others
	if [[ -n `adb $adb_on_device logcat -c -b crash | grep "Unable to open log device"` ]]; then
		crash_str=""
	else
		crash_str="-b crash"
	fi
}

parse_options()
{
	# get product name => prada
	readonly product=`adb $adb_on_device shell "getprop ro.build.product" | tr -d '\r'` # why need tr here????

	# get current time => 2017-02-24@10-12
	readonly start_time=`date "+%F-%H-%M"` # `date "+%F@%T"`

	for opt do
		optarg=`expr "x$opt" : 'x[^=]*=\(.*\)'`
		case "$opt" in
			-s=*)
				device_id="$optarg"
				;;
			-p=*)
				profile_file=$profile_dir/"$optarg"
				;;
			-t=*)
				test_tag="$optarg"
				;;
			--help)
				show_help="yes"
				;;
			*)
				echo "Bad option $opt"
				show_help="yes"
		esac
	done

	if [[ "$show_help" == "yes" ]]; then
	  echo "./android_performance_tuning.sh [-s=device_id] [-p=your_profile] [-t=your_tag]"
	  echo ""
	  echo "profile args:"
	  echo "  __global__"
	  echo "    test_pkgs: packages will be tested"
	  echo "    test_loops: loops will be iterated"
	  echo "    get_systrace: capture systrace when launching app"
	  echo ""
	  echo "  __action_before_test__"
	  echo "    shell script will be executed before test"
	  echo "      @arg1: test result dir"
	  echo ""
	  echo "  __action_before_loop__"
	  echo "    shell script will be executed before each loop"
	  echo "      @arg1: test result dir"
	  echo "      @arg2: loop index"
	  echo ""
	  echo "  __action_before_launch_app__"
	  echo "    shell script will be executed before launch app"
	  echo "      @arg1: test result dir"
	  echo "      @arg2: loop index"
	  echo "      @arg3: app index"
	  echo "      @arg4: package name"
	  echo ""
	  echo "  __action_after_launch_app__"
	  echo "    shell script will be executed after launch app"
	  echo "      @arg1: test result dir"
	  echo "      @arg2: loop index"
	  echo "      @arg3: app index"
	  echo "      @arg4: package name"

	  exit
	fi

	if [[ -z "$device_id" ]]; then
		device_id=`adb devices | grep -E "device$" | awk '{print $1}'`
	fi
	adb_on_device="-s $device_id"

	# check profile
	if [[ -z "$profile_file" ]]; then
		profile_file=$profile_dir/default.profile
	fi

	if [ ! -e $profile_file ]; then
		echo "profile $profile_file does not exist, exit!!"
		exit
	fi

	# define dir and files
	readonly device_dir=$out_dir/$product-$device_id
	if [[ -n "$test_tag" ]]; then
		readonly result_dir=$device_dir/$start_time-`basename $profile_file`-$test_tag
	else
		readonly result_dir=$device_dir/$start_time-`basename $profile_file`
	fi
	readonly action_dir=$result_dir/action

	readonly report_file=$result_dir/report.txt
	readonly report_mem_file=$result_dir/memory.csv
	readonly report_pkgs_launch_time_file=$result_dir/pkgs_launch_time.csv
	readonly log_file=$result_dir/log.txt

	readonly action_before_test_file=$action_dir/action_before_test.sh
	readonly action_before_loop_file=$action_dir/action_before_loop.sh
	readonly action_before_launch_app_file=$action_dir/action_before_launch_app.sh
	readonly action_after_launch_app_file=$action_dir/action_after_launch_app.sh

	# create dir
	if [ -d $result_dir ]; then
		echo "=> $result_dir already existed?? exit!!"
		exit
	else
		mkdir -p $result_dir
		mkdir -p $action_dir
	fi

	parse_profile $profile_file
}

#==================
# main()
#   arg1 - output result tag
#==================

main()
{
	#
	# global define
	#

	# dir
	readonly top_dir="`pwd`"
	readonly tools_dir=$top_dir/tools
	readonly out_dir=$top_dir/out
	readonly profile_dir=$top_dir/profile

	# file
	readonly pkgs_withoutui_file=$top_dir/pkgs_withoutui.txt # shared by all test

	# var
	declare -A args

	pkgs_name=()
	pkgs_name_launched=()
	declare -A pkgs_name2index  # [com.android.xx] <=> i

	parse_options $*

	echo "============================================================"
	echo "Start android performance tuning test at $start_time"
	echo "	Product   : $product"
	echo "	Device id : $device_id"
	echo "	output	  : $result_dir"
	echo "============================================================"

	run_action_before_test $result_dir

	install_tools

	# get system information, like lmk water mark, etc
	get_brief_info

	# get apps to launch
	get_packages

	for i in `eval echo {1..${args["test_loops"]}}`;
	do
		launch_apps $i
	done

	readonly end_time=`date "+%F@%H-%M"` # `date "+%F@%T"`

	echo "============================================================"
	echo "Android performance tuning test: $start_time ~ $end_time"
	echo "	output	  : $result_dir"
	echo "============================================================"
}

# pass all arguments to main()
main $*

# TODO:
#   pagetype info
#   zsmalloc info
