readonly fio_test_dir=/data/apt
readonly fio_benchmk_dir=fio/benchmark
readonly fio_config=basic-benchmk.fio

prepare_io_benchmk()
{
	echo -n "  prepare_io_benchmk..."
	adb $adb_on_device shell mkdir -p $fio_test_dir

	if [ -e "$fio_benchmk_dir/$fio_config" ]; then
		adb $adb_on_device push "$fio_benchmk_dir/$fio_config" $fio_test_dir &> /dev/null
		echo -e "[${GREEN}done${END}]"
	else
		echo -e "[${RED}error${END}]"
	fi

	mkdir -p .tmp
}

run_io_benchmk()
{
	local cur_out_dir=$1
	local loop_cnt=$2
	echo -n "  run_io_benchmk."
	adb $adb_on_device shell my_fio "$fio_test_dir/$fio_config" &> .tmp/.fio_rw
	if [ $? -eq 0 ]; then
		echo -n "."
		local fio_save=`cat .tmp/.fio_rw | grep "IOPS=" | awk '{print $2" "$3}' | sed 's/IOPS=\(.*\), BW=\(.*\)[KkMm].*/\1 \2/g' | xargs`
		echo -n "."
		echo -e "[${GREEN}$fio_save${END}]"
		echo "$loop_cnt $fio_save" >> $cur_out_dir/io_bench.txt 
	else
		echo -n ".."
		echo -e "[${RED}error${END}]"
	fi
	rm -rf .tmp/.fio_rw
}
