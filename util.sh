readonly RED="\033[31m"
readonly GREEN="\033[32m"
readonly RED_HI="\033[31,1m"
readonly END="\033[0m"

reboot_device()
{
	# reboot device
	echo "  reboot device"
	adb $adb_on_device shell reboot
	sleep 60

	adb $adb_on_device root
	sleep 10

	echo "  unlock screen"
	adb $adb_on_device shell input keyevent 26 # press power
	adb $adb_on_device shell input swipe 400 600 400 200 # swipe up to unlock screen

	#sleep 60 # 1 min
}

disable_verity()
{
	#1. check if it is root
	local whoami=`adb $adb_on_device shell whoami|tr -d '\r'`
	[ "$whoami" != "root" ] && adb $adb_on_device root > /dev/null && sleep 2

	#2. adb disable-verity if necessary
	echo -n "  check verity is disabled..."
	local adb_out=`adb $adb_on_device disable-verity|grep 'already disabled'`
	if [ "$adb_out" ]; then
		echo -e "[${GREEN}okay${END}]"
	else
		echo -e "[${RED}nope and reboot needed${END}]"

		echo -n "  disable verity..."
		adb $adb_on_device disable-verity &> /dev/null

		if [ $? -eq 0 ]; then
			echo -e "[${GREEN}done${END}]"
			reboot_device
		else
			echo -e "[${RED}error${END}]"
		fi
	fi

	#3. remount filesystem
	adb $adb_on_device remount &> /dev/null
}

print_spinner()
{
    local pid=$1
    local delay=0.35
    local spinstr='|/-\'

	while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "[${RED}%c${END}] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

check_and_wait_battery()
{
	local required_power=$1
	local power_level=`adb $adb_on_device shell dumpsys battery | grep level | tr -d '\r' | xargs | awk '{print $2}'`
	local display_status=`adb $adb_on_device shell dumpsys power | grep 'Display Power:' | sed 's/=/ /g' | tr -d '\r' | awk '{print $4}'`

	echo -n "check battery level..."
	if [ $power_level -lt $required_power ]; then
		echo -e "[${RED}low-${power_level}%${END}]"

		if [ "$display_status" = "ON" ]; then
			#closedisplay
			adb $adb_on_device shell input keyevent 26
			sleep 1
		fi

		local flag=0
		while [ $power_level -lt $required_power ];
		do
			if [ $flag -eq 0 ]; then
				echo -n "  battery charging."
				flag=1
			else
				echo -n .
			fi
			sleep 60
			power_level=`adb $adb_on_device shell dumpsys battery | grep level | tr -d '\r' | xargs | awk '{print $2}'`
		done
		echo -e "[${GREEN}done${END}]"
	else
		echo -e "[${GREEN}okay${END}]"
	fi

	display_status=`adb $adb_on_device shell dumpsys power | grep 'Display Power:' | sed 's/=/ /g' | tr -d '\r' | awk '{print $4}'`

	if [ "$display_status" = "OFF" ]; then
		adb $adb_on_device shell input keyevent 26
		adb $adb_on_device shell input swipe 400 600 400 200
		sleep 1
	fi
}
