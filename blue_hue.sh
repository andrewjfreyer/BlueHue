#!/bin/bash
# ----------------------------------------------------------------------------------------
# VERSION INFORMATION
# ----------------------------------------------------------------------------------------

# Written by Andrew J Freyer
# Version 1.72

# ----------------------------------------------------------------------------------------
# BASH API / NOTIFICATION API INCLUDE & VAR SETTING
# ----------------------------------------------------------------------------------------

source /home/pi/hue/support/hue_bashlibrary.sh
source /home/pi/hue/support/credentials
NOTIFICATIONSOURCE=/home/pi/hue/support/notification.sh ; [ -f $NOTIFICATIONSOURCE ] && source $NOTIFICATIONSOURCE

# ----------------------------------------------------------------------------------------
# Credential Information Verification
# ----------------------------------------------------------------------------------------

if [ -z $devicetype ] ||  [ -z $username ] || [ -z $macaddress ] || [ -z $devicename ]; then 
	echo "error: please supply credentials"
	exit 127
fi 

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

delaywhilepresent=60 			#higher means slower turn off when leaving
delaywhileabsent=10  			#higher means slower recognition when turning on 
delaywhileverify=5 				#higher means slower verification of absence times
delayafterconnection=5 
defaultwait=20
verifyrepetitions=2 		#lower means more false rejection 
laststatus=99

# ----------------------------------------------------------------------------------------
# Notification
# ----------------------------------------------------------------------------------------

function notify () {
	if [ ! -z "$1" ]; then 
		[ -f $NOTIFICATIONSOURCE ] && notifyViaPushover "$1"
	fi
}

# ----------------------------------------------------------------------------------------
# INFINITE LOOP
# ----------------------------------------------------------------------------------------

notify "BlueHue Proxmity Started."

while ($1); do
	for repetition in $(seq 1 $verifyrepetitions); 
	do 
		bluetoothscanresults=$(hcitool name "$macaddress" 2>&1)		
		bluetoothdevicepresent=$(echo "$bluetoothscanresults" | grep -ic "$devicename")

		if [ "$bluetoothscanresults" == "" ]; then
			if [ "$laststatus" != 0 ]; then  
				if [ "$repetition" -eq $verifyrepetitions ] ; then 
					#bluetooth device left
					notify "All lights have been turned off."
					hue_alloff
					laststatus=0
					defaultwait=$delaywhileabsent
					break
				fi
			else
				#bluetooth device remains absent
				defaultwait=$delaywhileabsent
				break
			fi 
			sleep "$delaywhileverify"

		elif [ "$bluetoothdevicepresent" == "1" ]; then 
			if [ "$laststatus" != 1 ]; then  
				#bluetooth device arrived
				notify "All lights have been turned on."
				hue_allon_custom
				laststatus=1
			else
				#bluetooth device remains present.
				defaultwait=$delaywhilepresent
			fi
			break
		else
			echo "Unknown state."
		fi
	done
	sleep "$defaultwait"
done
