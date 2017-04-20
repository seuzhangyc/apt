#
# templete profile
#

==> __global__

test_pkgs=50
test_loops=100

==> __action_before_test__

result_dir=$1

# your actions

==> __action_before_loop__

result_dir=$1
loop=$2

is_odd=$((loop%2))

if [ $is_odd -eq 1 ]; then
	echo "ui rt io" >> $result_dir/$loop/changes.txt
	# actions   
else
	echo "ui io normal" >> $result_dir/$loop/changes.txt
	# actions
fi

reboot_device

# your actions

==> __action_before_launch_app__

result_dir=$1
loop=$2
i=$3
p=$4

# your actions

==> __action_after_launch_app__

result_dir=$1
loop=$2
i=$3
p=$4

# your actions

