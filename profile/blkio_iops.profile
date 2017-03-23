#
# set iops limit for bg io cgroup
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_loop__

loop=$1
loop_dir=$2
is_odd=$((loop%2))

reboot_device

if [ $is_odd -eq 1 ]; then
	echo "bg io cgroup iops 300" >> $loop_dir/changes.txt
	adb shell "echo 253:0 300 > /dev/cpuset/background/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 300 > /dev/cpuset/background/blkio.throttle.read_iops_device"
else
	echo "bg io cgroup iops unlimited" >> $loop_dir/changes.txt

	adb shell "echo 253:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"
fi

==> __action_before_launch_app__

==> __action_after_launch_app__


