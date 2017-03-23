#
# process reclaim
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
	echo "enable process reclaim" >> $loop_dir/changes.txt

	adb shell "echo 1 > /sys/module/process_reclaim/parameters/enable_process_reclaim"
	# adb shell "setprop persist.sys.process_reclaim true"
else
	echo "disable process reclaim" >> $loop_dir/changes.txt

	adb shell "echo 0 > /sys/module/process_reclaim/parameters/enable_process_reclaim"
	# adb shell "setprop persist.sys.process_reclaim false"
fi

==> __action_before_launch_app__

==> __action_after_launch_app__


