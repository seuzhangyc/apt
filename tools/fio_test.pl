#! /usr/bin/perl

use strict;
use warnings;

my $lpCnt;
my $statsRpt;
my $fioCmd;
my $totalCnt=1;
my $deviceId;
my $adbs;
my @fields;
my @read_iops;
my @read_bw;
my @write_iops;
my @write_bw;
my $time;

foreach(@ARGV)
{
	if(/--time=(\d+)/) { $totalCnt = $1; }
	elsif(/--device=(.*)/) { $deviceId = $1; }
	else { print "$0 --time=<x> --device=<id>\n"; exit;}
}

if($deviceId) { $adbs = "-s $deviceId"; }
else { $adbs = ''; }

chop($time = `date -u | awk '{print \$5}' | sed 's/:/_/g'`);
open(W, ">blk_$time.log") or die "Failed to open blk.log";

die "Device ID is invlaid:$deviceId\n" unless `adb $adbs root`;
`adb $adbs shell mkdir -p data/iotest`;
#`adb $adbs shell stop`;
`adb $adbs shell 'echo 3 > /proc/sys/vm/drop_caches'`;

$fioCmd = "adb $adbs shell my_fio --name=global --filename=data/iotest/test0 ".
          "--ioengine=psync --direct=1 --rw=readwrite --size=500m ". 
		  "--timeout=60s --bs=4k --numjobs=1 ".
		  "--rwmixread=50 --name=TEST0 --prio=0 --prioclass=1 --name=TEST1";

for($lpCnt=0; $lpCnt<$totalCnt; $lpCnt++)
{
		print "Round $lpCnt -> ";
		$statsRpt = `$fioCmd`;
		print $fioCmd."\n";

		#print $statsRpt;

		#TEST 0 Read
		if($statsRpt =~ s/read:.*IOPS=(\d+),.*BW=(\d+)//)
		{
			print "    R: (0) IOPS=".$1." BW=".$2." ";
			print W "$1 ";
		}
		
		#TEST 1 Read
		if($statsRpt =~ s/read:.*IOPS=(\d+),.*BW=(\d+)//)
		{
			print "(1) IOPS=".$1." BW=".$2." ";
			print W "$1 ";
		}

		#TEST 0 write
		if($statsRpt =~ s/write:.*IOPS=(\d+),.*BW=(\d+)//)
		{
			print "W: (0) IOPS=".$1." BW=".$2." ";
			print W "$1 ";
	    }
		
		#TEST 1 write
		if($statsRpt =~ s/write:.*IOPS=(\d+),.*BW=(\d+)//)
		{
			print "(1) IOPS=".$1." BW=".$2."\n";
			print W "$1\r\n";
	    }
		
		sleep(1);
}
close(W);
