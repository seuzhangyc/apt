#
# set ui/render thread io rt class
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_test__

result_dir=$1

fio_file=fio/simple_read.fio

adb shell mkdir -p /data/apt/fio
adb push $fio_file /data/apt/fio > /dev/null
cp $fio_file $result_dir

==> __action_before_loop__

result_dir=$1
loop=$2

fio_file=fio/simple_read.fio

is_odd=$((loop%2))

if [ $is_odd -eq 1 ]; then
	echo "ui rt io" >> $result_dir/$loop/changes.txt

	adb shell "setprop persist.sys.ui_rtio 1"
else
	echo "ui io normal" >> $result_dir/$loop/changes.txt

	adb shell "setprop persist.sys.ui_rtio 0"
fi

reboot_device

adb remount
sleep 2
adb shell "my_fio /data/apt/$fio_file" &

==> __action_before_launch_app__

==> __action_after_launch_app__


