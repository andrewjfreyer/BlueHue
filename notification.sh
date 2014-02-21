#!/bin/bash

# ----------------------------------------------------------------------------------------
# NOFIFCATION FUNCTION
# ----------------------------------------------------------------------------------------

$PushoverToken=EnterYourPushoverToken
$PushoverUserKey=EnterYourPushoverUserKey

function notifyViaPushover () {
	if [ ! -z $PushoverUserKey ] && [ ! -z $PushoverToken ];then 
		curl -s \
			-F "token=$PushoverToken" \
			-F "user=$PushoverUserKey" \
			-F "message=$1" \
			"https://api.pushover.net/1/messages.json"
	fi
}