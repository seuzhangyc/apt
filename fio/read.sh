[global]
bs=4k
direct=1
ioengine=mmap
#iodepth=10
#filename=/dev/block/dm-0
runtime=30
size=100M
time_based



#----------------------------

[case1-blkio-fg]
rw=randwrite

# io class
#prioclass=0
#prio=0

cgroup=foreground
cgroup_weight=100
#rate_iops=100

#cpus_allowed=4

numjobs=1

#----------------------------

[case1-blkio-top-app]
rw=randwrite

# io class
#prioclass=1
#prio=0

cgroup=top-app
cgroup_weight=1000
#rate_iops=100

#cpus_allowed=4

numjobs=1

#----------------------------

[case2-blkio-bg]
rw=randwrite

# io class
#prioclass=0
#prio=0

cgroup=background
cgroup_weight=500
rate_iops=500

#cpus_allowed=4

numjobs=1

#----------------------------

#[randwrite]
#rw=randwrite
#numjobs=1
#rate_iops=100