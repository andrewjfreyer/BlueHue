#!/bin/bash

# ----------------------------------------------------------------------------------------
# VERSION INFORMATION
# ----------------------------------------------------------------------------------------

# Written by Andrew J Freyer

#Load the credential pages again
source /home/pi/hue/support/credentials_notification

function notifyViaPushover () {
	if [ ! -z $PushoverUserKey ] && [ ! -z $PushoverToken ];then 
		curl -s \
			-F "token=$PushoverToken" \
			-F "user=$PushoverUserKey" \
			-F "message=$1" \
			"https://api.pushover.net/1/messages.json"
	fi
}