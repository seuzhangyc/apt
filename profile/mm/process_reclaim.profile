#
# process reclaim
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_loop__

result_dir=$1
loop=$2

group=$((loop/10))
index=$((group%2))

reboot_device

if [ $index -eq 1 ]; then
	echo "enable process reclaim" >> $result_dir/$loop/changes.txt

	adb shell "echo 1 > /sys/module/process_reclaim/parameters/enable_process_reclaim"
else
	echo "disable process reclaim" >> $result_dir/$loop/changes.txt

	adb shell "echo 0 > /sys/module/process_reclaim/parameters/enable_process_reclaim"
fi

==> __action_before_launch_app__

==> __action_after_launch_app__


