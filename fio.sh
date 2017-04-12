readonly fio_test_dir="/data/apt"
readonly fio_benchmk_dir="fio/benchmark"
readonly fio_test_ini="basic-benchmk.fio"

prepare_io_benchmk()
{
	echo -n "  prepare_io_benchmk."

	# mkdir and clean kernel cache	
	adb $adb_on_device shell "mkdir -p $fio_test_dir && rm -rf $fio_test_dir/*"
	adb $adb_on_device shell 'echo 3 > /proc/sys/vm/drop_caches'
	sleep 1 && echo -n "."

	if [ "${args["io_benchmark_stopfw"]}" = "true" ]; then
		adb $adb_on_device shell stop &> /dev/null
		sleep 3
	fi
	echo -n "."
	
	if [ -e "$fio_benchmk_dir/$fio_config" ]; then
		adb $adb_on_device push "$fio_benchmk_dir/$fio_config" $fio_test_dir &> /dev/null
		echo -e "[${GREEN}done${END}]"
	else
		echo -e "[${RED}error${END}]"
	fi
}

run_io_benchmk()
{
	local cur_out_dir=$1
	local cur_loop_cnt=$2
	local bench_res_file="$cur_out_dir/io_bench.csv"
	local bench_ini_file="$fio_test_dir/$fio_test_ini"
	local bench_log_file="$cur_out_dir/$cur_loop_cnt/1-log/fio.txt"

	# mkdir log directory
	if [ ! -d "${bench_log_file%/*}" ]; then
		mkdir -p ${bench_log_file%/*}
	fi

	# print table header (exec once)
	if [ ! -e $bench_res_file ]; then
		echo "loop R-iops R-bw W-iops W-bw RR-iops RR-bw RW-iops RW-bw"\
				> $bench_res_file
	fi

	# kick off io testing
	echo -n "  run_io_benchmk."
	adb $adb_on_device shell my_fio $bench_ini_file &> $bench_log_file &
	print_spinner $!
	if [ $? -eq 0 ]; then
		echo -n "."
		local fio_save=$(cat $bench_log_file | grep "IOPS=" | awk '{print $2" "$3}' | sed 's/IOPS=\(.*\), BW=\(.*\)[KkMm].*/\1 \2/g' | xargs)
		sleep 1
		echo -n "."
		echo -e "[${GREEN}$fio_save${END}]"
		echo "$cur_loop_cnt $fio_save" >> $bench_res_file
	else
		echo -n "." && sleep 1 && echo -n "."
		echo -e "[${RED}error${END}]"
	fi
}

endup_io_benchmk()
{
	# clean io test files
	adb $adb_on_device shell rm -rf $fio_test_dir

	# restore fw if disabled
	if [ "${args["io_benchmark_stopfw"]}" = "true" ]; then
		adb $adb_on_device shell start &> /dev/null
	fi
}
