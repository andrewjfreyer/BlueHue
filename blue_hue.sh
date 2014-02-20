#!/bin/bash
# ----------------------------------------------------------------------------------------
# VERSION INFORMATION
# ----------------------------------------------------------------------------------------

# Written by Andrew J Freyer
# Version 1.0

# ----------------------------------------------------------------------------------------
# BASH API INCLUDE & VAR SETTING
# ----------------------------------------------------------------------------------------

source /home/pi/hue/hue_bashlibrary.sh
devicetype='api'							
username='yourusernamehere'
loglevel=0
laststatus=99

# ----------------------------------------------------------------------------------------
# GET THE IP OF THE BRIDGE
# ----------------------------------------------------------------------------------------

#Find the IP Address of the Bridge
ip=$(cat /home/pi/hue/hue_ip)

if [ -z "$ipaddress" ]; then 
	ip=$(curl -s http://www.meethue.com/api/nupnp | grep -ioE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
	echo "$ip" > /home/pi/hue/hue_ip
fi

# ----------------------------------------------------------------------------------------
# DEFAULTS WAIT SETTINGS
# ----------------------------------------------------------------------------------------

DefaultWaitWhilePresent=25
DefaultWaitWhileAbsent=10
DefaultWaitWhileVerify=3
DefaultWait=10
DefaultRepeatSequence=10

# ----------------------------------------------------------------------------------------
# COLOR PER TIME OF DAY
# ----------------------------------------------------------------------------------------

function hue_allon_custom () {
	# Range of hue: 0 and 65535. Both 0 and 65535 are red, 25500 is green and 46920 is blue.

	bri=0 #0 - 255
	hue=0 #0 - 65535
	sat=0 #0 - 255

	hour=$(date "+%H")

	if ((4<=hour && hour<=6)); then
		#early morning -> light blue at low brighness
		bri=50
		hue=46920
		sat=120
	elif ((7<=hour && hour<=10)); then
		#mid morning -> warm (red) white light
		bri=255
		hue=65535
		sat=25
	elif ((11<=hour && hour<=13)); then
	    #noon  -> white
		bri=255
		hue=0
		sat=0
	elif ((13<=hour && hour<=16)); then
	    #afternoon -> cool (blue) white light
		bri=200
		hue=46920
		sat=25
	elif ((17<=hour && hour<=21)); then
	    #evening -> cool (blue) white light
	    bri=180
		hue=46920
		sat=225
	elif ((21<=hour && hour<=23)); then
	    #night -> cool (blue) white light; moon
	    bri=160
		hue=46920
		sat=255
	elif ((0<=hour && hour<=3)); then
	    #late night -> cool (blue) white light; dim moon
	    bri=130
		hue=46920
		sat=255
	fi

	hue_allon $hue $sat $bri
}


# ----------------------------------------------------------------------------------------
# NOFIFCATION FUNCTION
# ----------------------------------------------------------------------------------------

function notifyViaPushover () {
	curl -s \
		-F "token=" \
		-F "user=" \
		-F "message=$1" \
		"https://api.pushover.net/1/messages.json"
}

# ----------------------------------------------------------------------------------------
# INFINITE LOOP
# ----------------------------------------------------------------------------------------

notifyViaPushover "Rebooted."

while ($1); do
	for repetition in $(seq 1 $DefaultRepeatSequence); 
	do 
		ScanResult=$(hcitool name 0C:3E:9F:54:FD:DC 2>&1)
		iPhonePresent=$(echo "$ScanResult" | grep -ic "iPhone")

		if [ "$ScanResult" == "" ]; then
			if [ "$laststatus" != 0 ]; then  
				if [ "$repetition" -eq $DefaultRepeatSequence ] ; then 
					#iPhone left
					notifyViaPushover "All lights have been turned off."
					hue_alloff
					laststatus=0
					DefaultWait=$DefaultWaitWhileAbsent
					break
				fi
			else
				#iPhone remains absent
				DefaultWait=$DefaultWaitWhileAbsent
				break
			fi 
			sleep "$DefaultWaitWhileVerify"

		elif [ "$iPhonePresent" == "1" ]; then 
			if [ "$laststatus" != 1 ]; then  
				#iPhone arrived
				notifyViaPushover "All lights have been turned on."
				hue_allon_custom
				laststatus=1
			else
				#iPhone remains present.
				DefaultWait=$DefaultWaitWhilePresent
			fi
			break
		else
			echo "Unknown state."
		fi
	done
	sleep "$DefaultWait"
done
