#!/bin/bash

# ----------------------------------------------------------------------------------------
# NOFIFCATION FUNCTION
# ----------------------------------------------------------------------------------------

#Load the credential pages again
credentials=$(cat /home/pi/hue/hue_credentials)

#Download the credentials 
$PushoverToken=$(echo "$credentials" | awk '{print $5}')
$PushoverUserKey=$(echo "$credentials" | awk '{print $4}')

function notifyViaPushover () {
	if [ ! -z $PushoverUserKey ] && [ ! -z $PushoverToken ];then 
		curl -s \
			-F "token=$PushoverToken" \
			-F "user=$PushoverUserKey" \
			-F "message=$1" \
			"https://api.pushover.net/1/messages.json"
	fi
}