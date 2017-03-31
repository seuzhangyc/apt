#
# 1. set ui/render thread as io rt class
# 2. limit bg_non_interactive group read iops
# 3. simulation background io scenario
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_test__

result_dir=$1

adb shell mkdir -p /data/apt
adb push fio/simple_read.fio /data/apt > /dev/null

cp fio/simple_read.fio $result_dir/

==> __action_before_loop__

result_dir=$1
loop=$2

is_odd=$((loop%2))

adb shell setprop persist.sys.ui_fifo 0

if [ $is_odd -eq 1 ]; then
	adb shell setprop persist.sys.ui_rtio 1
else
	adb shell setprop persist.sys.ui_rtio 0
fi

reboot_device

if [ $is_odd -eq 1 ]; then
	echo "bg cgroup blkio iops 300" >> $result_dir/$loop/changes.txt

	adb shell "echo 253:0 300 > /dev/cpuctl/bg_non_interactive/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 300 > /dev/cpuctl/bg_non_interactive/blkio.throttle.read_iops_device"
else
	echo "bg group iops unlimited" >> $result_dir/$loop/changes.txt

	adb shell "echo 253:0 0 > /dev/cpuctl/bg_non_interactive/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 0 > /dev/cpuctl/bg_non_interactive/blkio.throttle.read_iops_device"
fi

#adb shell "my_fio /data/apt/simple_read.fio" &
#sleep 2

==> __action_before_launch_app__

adb shell "my_dd if=/dev/block/dm-0 of=/dev/null bs=4k count=20480 iflag=direct" &
adb shell "my_dd if=/dev/block/dm-0 of=/dev/null bs=4k count=20480 iflag=direct" &
adb shell "my_dd if=/dev/block/bootdevice/by-name/cust of=/dev/null bs=4k count=20480 iflag=direct" &
adb shell "my_dd if=/dev/block/bootdevice/by-name/system of=/dev/null bs=4k count=20480 iflag=direct" &

pids=`adb shell ps | grep my_dd | awk '{print $2}'`
for i in $pids
do		
	adb shell ionice $i be 1
done

sleep 1

==> __action_after_launch_app__
