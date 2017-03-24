[global]
bs=4k
direct=1
ioengine=mmap
#iodepth=10
runtime=10
size=200M
time_based

#----------------------------

[case1-blkio-bg]
filename=/dev/block/dm-0
rw=randread

# io class
#prioclass=0
#prio=0

cgroup=background
#cgroup_weight=500
#rate_iops=500

#cpus_allowed=4

numjobs=1

#----------------------------

[case2-blkio-bg]
filename=/dev/block/mmcblk0
rw=randread

# io class
#prioclass=0
#prio=0

cgroup=background
#cgroup_weight=500
#rate_iops=500

#cpus_allowed=4

numjobs=1