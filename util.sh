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

