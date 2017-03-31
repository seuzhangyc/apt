#
# set iops limit for bg io cgroup
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_test__

result_dir=$1

adb shell mkdir -p /data/apt
adb push fio/blkio_bg_read.sh /data/apt > /dev/null

cat fio/blkio_bg_read.sh >> $result_dir/report.txt

==> __action_before_loop__

result_dir=$1
loop=$2

is_odd=$((loop%2))

reboot_device

if [ $is_odd -eq 1 ]; then
	echo "bg io cgroup iops 300" >> $result_dir/$loop/changes.txt

	adb shell "echo 253:0 300 > /dev/cpuset/background/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 300 > /dev/cpuset/background/blkio.throttle.read_iops_device"
else
	echo "bg io cgroup iops unlimited" >> $result_dir/$loop/changes.txt

	adb shell "echo 253:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"
fi

==> __action_before_launch_app__

adb shell "my_fio /data/apt/blkio_bg_read.sh" &
sleep 2

==> __action_after_launch_app__
