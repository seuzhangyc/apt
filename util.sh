
reboot_device()
{	
	# reboot device
	echo "  reboot device"
	adb $adb_on_device shell reboot
	sleep 60 # 1 min

	adb $adb_on_device root
	echo "  unlock screen"
	adb $adb_on_device shell input keyevent 26 # press power
	adb $adb_on_device shell input swipe 400 600 400 200 # swipe up to unlock screen

	#sleep 60 # 1 min
}
