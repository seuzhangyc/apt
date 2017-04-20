sig_kill_handler()
{
	endup_io_benchmk

	echo "Exit..."

	exit
}

trap sig_kill_handler SIGINT SIGQUIT SIGKILL SIGTERM
