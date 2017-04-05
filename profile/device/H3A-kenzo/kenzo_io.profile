#
# ionice and bg iops limit test
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_test__

result_dir=$1

fio_file=fio/blkio/blkio_bg_rw_timeout.fio

adb shell mkdir -p /data/apt/fio
adb push $fio_file /data/apt/fio > /dev/null

cp $fio_file $result_dir

adb shell setprop persist.sys.ui_fifo 0
adb shell setprop persist.sys.ui_rtio 0

==> __action_before_loop__

result_dir=$1
loop=$2

is_odd=$((loop%2))

if [ $is_odd -eq 1 ]; then
	echo "enable rtio" >> $result_dir/$loop/changes.txt
	adb shell setprop persist.sys.ui_rtio 1	
else
	echo "disable rtio" >> $result_dir/$loop/changes.txt
	adb shell setprop persist.sys.ui_rtio 0
fi

reboot_device

if [ $is_odd -eq 1 ]; then
	echo "set blkio_bg_iops_limit 1" >> $result_dir/$loop/changes.txt

	adb shell setprop persist.sys.blkio_bg_iops_limit 1
	#adb shell "echo 253:0 300 > /dev/cpuctl/bg_non_interactive/blkio.throttle.read_iops_device"
	#adb shell "echo 179:0 300 > /dev/cpuctl/bg_non_interactive/blkio.throttle.read_iops_device"

else
	adb shell setprop persist.sys.blkio_bg_iops_limit 0
	echo "unlimited bg group iops" >> $result_dir/$loop/changes.txt
fi

adb shell cat /dev/cpuctl/bg_non_interactive/blkio.throttle.read_iops_device >> $result_dir/$loop/changes.txt
adb shell cat /dev/cpuctl/bg_non_interactive/blkio.throttle.write_iops_device >> $result_dir/$loop/changes.txt

==> __action_before_launch_app__

adb shell "my_fio /data/apt/fio/blkio_bg_rw_timeout.fio" &
sleep 2

==> __action_after_launch_app__
