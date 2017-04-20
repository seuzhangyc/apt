#
# set weight of each io cgroup
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_loop__

result_dir=$1
loop=$2

is_odd=$((loop%2))

reboot_device

if [ $is_odd -eq 1 ]; then
	echo "set weight for io cgroup" >> $result_dir/$loop/changes.txt

	adb shell "echo 200 > /dev/cpuset/blkio.leaf_weight"
	adb shell "echo 1000 > /dev/cpuset/top-app/blkio.weight"
	adb shell "echo 300 > /dev/cpuset/foreground/blkio.weight"
	adb shell "echo 100 > /dev/cpuset/background/blkio.weight"
	adbshell "echo 100 > /dev/cpuset/system-background/blkio.weight"
else
	echo "use defult weight for io cgroup" >> $result_dir/$loop/changes.txt

	adb shell "echo 500 > /dev/cpuset/blkio.leaf_weight"
	adb shell "echo 500 > /dev/cpuset/top-app/blkio.weight"
	adb shell "echo 500 > /dev/cpuset/foreground/blkio.weight"
	adb shell "echo 500 > /dev/cpuset/background/blkio.weight"
	adbshell "echo 500 > /dev/cpuset/system-background/blkio.weight"
fi

==> __action_before_launch_app__

==> __action_after_launch_app__


