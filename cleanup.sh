#!/bin/bash
##### VARIABLES THAT YOU SHOULD MODIFY #####
HOST="%fqdn%"
USER="%user%"
PORT="22"
##### END OF VARIABLES #####

main() {
	cleanup
}

cleanup() {
	# local
	echo "Cleaning local machine..."
	LOCALRUN=$(systemd-path user-runtime)
	rm "$LOCALRUN/p11-kit"/*
	pkill -f p11-kit-server
	pkill -f p11-kit-remote
	pkill -f "ssh -N -f -R /run/user/"
	echo "Done"

	# distant
	echo "Cleaning distant machine..."
	DISTANTRUN=$(ssh $USER@$HOST -p "$PORT" systemd-path user-runtime)
	ssh "$USER"@"$HOST" -p "$PORT" rm "$DISTANTRUN/p11-kit"/*
	echo -n "Done\n"
}

main $*
