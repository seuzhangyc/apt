#
# default profile
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_loop__

loop=$1
loop_dir=$2
is_odd=$((loop%2))

if [ $is_odd -eq 1 ]; then
	echo "ui fifo" >> $loop_dir/changes.txt

	adb shell "setprop persist.sys.ui_fifo 1"
else
	echo "ui normal" >> $loop_dir/changes.txt

	adb shell "setprop persist.sys.ui_fifo 0"
fi

reboot_device

==> __action_before_launch_app__

==> __action_after_launch_app__


