#!/bin/bash
##### VARIABLES THAT YOU SHOULD MODIFY #####
HOST="%fqdn%"
USER="%user%"
PORT="22"
PROVIDERLIB="/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"
DISTANTPROVIDERLIB="/usr/local/lib/pkcs11/p11-kit-client.so"
EJBCASTOPCOMMAND="sudo systemctl stop ejbca.service"
EJBCASTARTCOMMAND="sudo systemctl start ejbca.service"
##### END OF VARIABLES #####

main() {
	echo "Remote HSM - v1.0"
	echo
	echo "This script will initiate a link between your local smartcard and a remote host. EJBCA will be restarted."
	echo
	echo "Parameters (edit this script to change them, starting line 3):"
	echo "Remote host: $HOST"
	echo "Remote user: $USER"
	echo "Local HSM library: $PROVIDERLIB"
	echo "Remote HSM library: $DISTANTPROVIDERLIB"
	echo

	read -p "Want to continue? (y/n) : " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		# Init
		testinit
		if [[ $? == 1 ]]
		then
			init
		fi

		# Init remote
		testinitremote
		if [[ $? == 1 ]]
		then
			initremote
		fi

		# Test remote if share seems already running
		servertest
		if [[ $? == 0 ]]
		then
			read -p "HSM seems already available on remote host, running this script again might be useless. Are your REALLY sure you want to continue? (y/n) : " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]
			then
				echo
			else
				echo
				exit 1
			fi

		fi
		mainjob
	fi
	echo
}

mainjob() {
    cleanup
    testserverstart
    serverstart
    servertest
    testejbca
    ejbcarestart
    success
}

testinit() {
	echo -e "Verifying if systemd user service is enabled (local)...\n"
	if systemctl --user status p11-kit-client.service | grep "Active: active" > /dev/null
	then
		echo -e "Local has user service running.\n"	
	    return 0;
	else
	    return 1;
	fi
}

testinitremote() {
	echo -e "Verifying if systemd user service is enabled (remote)...\n"
	if ssh "$USER"@"$HOST" -p "$PORT" systemctl --user status p11-kit-client.service | grep "Active: active" > /dev/null
	then
		echo -e "Remote has user service running.\n"
	    return 0;
	else
	    return 1;
	fi
}

init() {
	# Enabling systemctl daemon for keeping folder
	echo "Enabling p11-kit-client.service (local)..."
	systemctl --user enable p11-kit-client.service
	systemctl --user start p11-kit-client.service
	echo -e "Done\n"
}

initremote() {
	# Enabling systemctl daemon for keeping folder
	echo "Enabling p11-kit-client.service (distant)..."
	ssh "$USER"@"$HOST" -p "$PORT" systemctl --user enable p11-kit-client.service
	ssh "$USER"@"$HOST" -p "$PORT" systemctl --user start p11-kit-client.service
	echo -e "Done\n"
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

testserverstart() {
	if [[ -f "$PROVIDERLIB" ]]
	then
		return
	else
		echo "$PROVIDERLIB does not exist on local machine. Exiting."
		exit 1;
	fi

	ssh "$USER"@"$HOST" -p "$PORT" -f "$DISTANTPROVIDERLIB"
	if [[ $? -ne 0 ]]
	then
		echo "$DISTANTPROVIDERLIB does not exist on local machine. Exiting."
		exit 1;
	fi
}

serverstart() {
	# Get URL of token
	echo "Getting Token URL..."
	TOKENURL=$(p11tool --provider "$PROVIDERLIB" --list-token-urls)
	echo "Token URL is $TOKENURL"
	# Start server and set ENV vars
	echo "Starting server and setting env vars..."
	SERVERVARS=$(p11-kit server --provider "$PROVIDERLIB" "$TOKENURL")
	eval $SERVERVARS
	echo "Done, local socket is at ${P11_KIT_SERVER_ADDRESS#*=}"
	# Check unix socket exists
	echo "SSH tunneling the socket to remote EJBCA instance"
	nohup ssh  -p "$PORT" -N -f -R "$DISTANTRUN/p11-kit/pkcs11":${P11_KIT_SERVER_ADDRESS#*=} "$USER"@"$HOST"
	echo -e "SSH tunneling done, remote socket is at $HOST:$DISTANTRUN/p11-kit/pkcs11\n"
}

servertest() {
	echo "Testing remote access to smartcard..."
	TESTRES=$(ssh "$USER"@"$HOST" -p "$PORT" pkcs11-tool --module "$DISTANTPROVIDERLIB" -L 2>&1)
	echo "Test result:"
	echo "$TESTRES"
	if [[ $(grep "No slots." <<< $TESTRES) ]]
	then
		return 1;
	else
		return 0;
	fi
}

testejbca()
{
	echo "Testing remote for EJBCA installation..."
	ssh "$USER"@"$HOST" -p "$PORT" "[ -d ejbca ]"
	if [[ $? -ne 0 ]]
	then
		echo "EJBCA is not existing in home folder of remote user. Exiting script."
		exit 1;
	else
		ssh "$USER"@"$HOST" -p "$PORT" "[ -d wildfly ]"
		if [[ $? -ne 0 ]]
		then
			echo "EJBCA is not existing in home folder of remote user. Exiting script."
			exit 1;
		fi
	fi
	echo -e "EJBCA seems installed on remote.\n"
}

ejbcarestart() {
	echo "Restarting EJBCA to ensure recognition of the remote-ed HSM..."
	ssh "$USER"@"$HOST" -p "$PORT" "$EJBCASTOPCOMMAND"
	ssh "$USER"@"$HOST" -p "$PORT" "$EJBCASTARTCOMMAND"
	echo -e "EJBCA restarted, please wait 20 seconds and connect to EJBCA to add HSM to EJBCA cryptotoken.\n"
}

success() {
	echo -e "Script is successful.\n"
}

main $*
