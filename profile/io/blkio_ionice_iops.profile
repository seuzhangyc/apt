#
# set iops limit for bg io cgroup
#

==> __global__

test_pkgs=100
test_loops=1000

==> __action_before_test__

result_dir=$1

adb shell mkdir -p /data/apt
adb push fio/blkio_bg_rw.fio /data/apt > /dev/null

# save this file
echo -e "\n------ profile ------\n" >> $result_dir/report.txt
echo -e "1-9 enable ionice+limit" >> $result_dir/report.txt
echo -e "10-19 enable ionice" >> $result_dir/report.txt
echo -e "20-29 default" >> $result_dir/report.txt

echo -e "\n------ fio ------\n" >> $result_dir/report.txt
cat fio/blkio_bg_rw.fio >> $result_dir/report.txt

==> __action_before_loop__

result_dir=$1
loop=$2

group=$((loop/10))
index=$((group%3))

if [ $index -eq 0 ]; then
	echo "ui rt io" >> $result_dir/$loop/changes.txt

	adb shell "setprop persist.sys.ui_rtio true"	
elif [ $index -eq 1 ]; then
	echo "ui rt io" >> $result_dir/$loop/changes.txt

	adb shell "setprop persist.sys.ui_rtio true"

elif [ $index -eq 2 ]; then
	echo "ui io normal" >> $result_dir/$loop/changes.txt

	adb shell "setprop persist.sys.ui_rtio false"
fi

reboot_device

adb shell "my_fio /data/apt/blkio_bg_rw.fio" &
sleep 2

if [ $index -eq 0 ]; then
	echo "bg io cgroup iops 300" >> $result_dir/$loop/changes.txt

	adb shell "echo 253:0 300 > /dev/cpuset/background/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 300 > /dev/cpuset/background/blkio.throttle.read_iops_device"
elif [ $index -eq 1 ]; then
	echo "bg io cgroup iops unlimited" >> $result_dir/$loop/changes.txt

	adb shell "echo 253:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"	

elif [ $index -eq 2 ]; then

	echo "bg io cgroup iops unlimited" >> $result_dir/$loop/changes.txt

	adb shell "echo 253:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"
	adb shell "echo 179:0 0 > /dev/cpuset/background/blkio.throttle.read_iops_device"
fi

==> __action_before_launch_app__



==> __action_after_launch_app__
