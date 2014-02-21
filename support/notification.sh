#!/bin/bash

# ----------------------------------------------------------------------------------------
# NOFIFCATION FUNCTION
# ----------------------------------------------------------------------------------------

#Load the credential pages again
credentials=$(cat /home/pi/hue/support/notification_credentials)

#Download the credentials 
PushoverToken=$(echo "$credentials" | awk '{print $2}')
PushoverUserKey=$(echo "$credentials" | awk '{print $1}')

function notifyViaPushover () {
	if [ ! -z $PushoverUserKey ] && [ ! -z $PushoverToken ];then 
		curl -s \
			-F "token=$PushoverToken" \
			-F "user=$PushoverUserKey" \
			-F "message=$1" \
			"https://api.pushover.net/1/messages.json"
	fi
}