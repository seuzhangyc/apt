#
# ui/render thread io rt nice profile
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_loop__

loop=$1
loop_dir=$2
is_odd=$((loop%2))

if [ $is_odd -eq 1 ]; then
	echo "ui rt io" >> $loop_dir/changes.txt

	adb shell "setprop persist.sys.ui_rtio 1"
else
	echo "ui io normal" >> $loop_dir/changes.txt

	adb shell "setprop persist.sys.ui_rtio 0"
fi

reboot_device

==> __action_before_launch_app__

==> __action_after_launch_app__


