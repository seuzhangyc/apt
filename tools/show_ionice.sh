#!/bin/bash

if [ $# -lt 1 ]; then
	echo "Usage:"
	echo "    show_ionice.sh pid"
fi

pid=$1

for i in `adb shell ps -t $PID | sed '1d'  | awk '{print $2}'`
do 
	name=`ps -t | grep " $i " | awk '{print $9}'`
	result=`adb shell ionice $i`
	echo "$result => $name"
done



