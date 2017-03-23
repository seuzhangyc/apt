[global]
bs=4k
direct=1
ioengine=mmap
#iodepth=10
filename=/dev/block/dm-0
runtime=10
size=200M
time_based

#----------------------------

[case2-blkio-bg]
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

#[randwrite]
#rw=randwrite
#numjobs=1
#rate_iops=100