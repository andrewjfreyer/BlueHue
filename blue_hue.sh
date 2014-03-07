#!/bin/bash
# ----------------------------------------------------------------------------------------
# VERSION INFORMATION
# ----------------------------------------------------------------------------------------

# Written by Andrew J Freyer
# Version 1.3

# ----------------------------------------------------------------------------------------
# BASH API / NOTIFICATION API INCLUDE & VAR SETTING
# ----------------------------------------------------------------------------------------

source /home/pi/hue/support/hue_bashlibrary.sh

if [ ! -f "/home/pi/hue/support/credentials" ]; then 
	echo "BlueHue Requires Credentials"
	exit 127
else
	source /home/pi/hue/support/credentials
fi 

#Support Notifications?
NOTIFICATIONSOURCE=/home/pi/hue/support/notification.sh ; [ -f $NOTIFICATIONSOURCE ] && source $NOTIFICATIONSOURCE

# ----------------------------------------------------------------------------------------
# Credential Information Verification
# ----------------------------------------------------------------------------------------

if [ -z $devicetype ] ||  [ -z $username ] || [ -z $macaddress ] || [ -z $devicename ]; then 
	echo "hue_credentials usage: devicetype username mac devicename"
	exit 1
fi 

# ----------------------------------------------------------------------------------------
# SOURCE VARIABLES FOR HUE API
# ----------------------------------------------------------------------------------------

loglevel=0
laststatus=99

# ----------------------------------------------------------------------------------------
# GET THE IP OF THE BRIDGE
# ----------------------------------------------------------------------------------------

#Find the IP Address of the Bridge
ip=$(cat /home/pi/hue/support/hue_ip)

if [ -z "$ipaddress" ]; then 
	ip=$(curl -s http://www.meethue.com/api/nupnp | grep -ioE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
	echo "$ip" > /home/pi/hue/support/hue_ip
fi

# ----------------------------------------------------------------------------------------
# DEFAULTS
# ----------------------------------------------------------------------------------------

DefaultWaitWhilePresent=60 	#higher means slower turn off when leaving
DefaultWaitWhileAbsent=10  	#higher means slower recognition when turning on 
DefaultWaitWhileVerify=5 	#higher means slower verification of absence times
DefaultWait=20
DefaultRepeatSequence=10 	#lower means more false rejection 

CurrentHour=$(date "+%H")
CurrentCalendarWhileAbsent=60

function notify () {
	if [ ! -z "$1" ]; then 
		[ -f $NOTIFICATIONSOURCE ] && notifyViaPushover "$1"
	fi
}

# ----------------------------------------------------------------------------------------
# COLOR PER TIME OF DAY
# ----------------------------------------------------------------------------------------

function hue_allon_custom () {
	# Range of hue: 0 and 65535. Both 0 and 65535 are red, 25500 is green and 46920 is blue.

	bri=0 #0 - 255
	hue=0 #0 - 65535
	sat=0 #0 - 255
    transition=10 #in 1/10 seconds

	hour=$(date "+%H")

	if ((4<=hour && hour<=6)); then
		#early morning -> light blue at low brighness
		bri=127
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
		bri=255
		hue=46920
		sat=25
	elif ((17<=hour && hour<=21)); then
	    	#evening -> cool (blue) white light
	    bri=230
		hue=46920
		sat=180
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

	#by default all lights will be turned on or off (i.e., group0)
	hue_allon $hue $sat $bri $transition
}


# ----------------------------------------------------------------------------------------
# INFINITE LOOP
# ----------------------------------------------------------------------------------------

notify "BlueHue Proxmity Started."

while ($1); do
	for repetition in $(seq 1 $DefaultRepeatSequence); 
	do 
		ScanResult=$(hcitool name "$macaddress" 2>&1)
		
		iPhonePresent=$(echo "$ScanResult" | grep -ic "$devicename")

		if [ "$ScanResult" == "" ]; then
			if [ "$laststatus" != 0 ]; then  
				if [ "$repetition" -eq $DefaultRepeatSequence ] ; then 
					#iPhone left
					update_calendar "depart"

					notify "All lights have been turned off."
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
				notify "All lights have been turned on."
				#update the arrival calendar
				update_calendar "arrive"

				#Turn all lights on
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
