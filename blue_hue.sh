#!/bin/bash

# ----------------------------------------------------------------------------------------
# GENERAL INFORMATION
# ----------------------------------------------------------------------------------------
#
# BlueHue - Bluetooth Proximity Switch for Hue Ligts
# Written by Andrew J Freyer
# Version 1.86
# GNU General Public License
#
# ----------------------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------
# BASH API / NOTIFICATION API INCLUDE
# ----------------------------------------------------------------------------------------

source /home/pi/hue/support/hue_bashlibrary.sh
source /home/pi/hue/support/credentials
NOTIFICATIONSOURCE=/home/pi/hue/support/notification.sh ; [ -f $NOTIFICATIONSOURCE ] && source $NOTIFICATIONSOURCE

# ----------------------------------------------------------------------------------------
# Set Program Variables
# ----------------------------------------------------------------------------------------

delaywhilepresent=80 			#higher means slower turn off when leaving
delaywhileabsent=8 				#higher means slower recognition when turning on 
delaywhileverify=6 				#higher means slower verification of absence times
defaultdelaybeforeon=1.5		#higher means slower turn on
delaybetweenscan=3				#advised for bluetooth hardware 
verifyrepetitions=7 			#lower means more false rejection 
ip=0.0.0.0 						#IP address filler

# ----------------------------------------------------------------------------------------
# Credential Information Verification
# ----------------------------------------------------------------------------------------

if [ -z $devicetype ] ||  [ -z $username ] || [ -z "$macaddress" ]; then 
	echo "error: please supply credentials"
	exit 127
fi 

# ----------------------------------------------------------------------------------------
# GET THE IP OF THE BRIDGE
# ----------------------------------------------------------------------------------------
function refreshIPAddress () {
	ip=$(cat /home/pi/hue/support/hue_ip)
	verifybridge=$(curl -m 1 -s "$ip/api" | grep -c "not available for resource")

	if [ -z "$ipaddress" ] || [ "$verifybridge" != "1" ]; then 
		ip=$(curl -s http://www.meethue.com/api/nupnp | grep -ioE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
		echo "$ip" > /home/pi/hue/support/hue_ip
	fi
}

# ----------------------------------------------------------------------------------------
# Notification
# ----------------------------------------------------------------------------------------

function notify () {
	if [ ! -z "$1" ]; then 
		[ -f $NOTIFICATIONSOURCE ] && notifyViaPushover "$1"
	fi
}

# ----------------------------------------------------------------------------------------
# PROGRAM LOOP
# ----------------------------------------------------------------------------------------

notify "BlueHue Proxmity Started."
defaultwait=0
laststatus=$(hue_all_status)

echo "LAST STATUS $laststatus"

if [ "$laststatus" == "1" ]; then
	notify "BlueHue Proximity Started. Lights are on."
else
	notify "BlueHue Proximity Started. Lights are off."
fi

exit

refreshIPAddress

while ($1); do	
	for repetition in $(seq 1 $verifyrepetitions); 
	do 
		bluetoothscanresults=""

		for searchdeviceaddress in $macaddress; 
		do 
			bluetoothscanresults="$bluetoothscanresults$(hcitool name "$searchdeviceaddress" 2>&1)"
			bluetoothdevicepresent=$(echo "$bluetoothscanresults" | grep -icE "[a-z0-9]")
			
			if [ "$bluetoothscanresults" != "" ]; then
 				#if at least one device was found continue
 				break
 			else
 				#else, continue with scan list
				sleep $delaybetweenscan
 			fi
		done

		if [ "$bluetoothscanresults" == "" ]; then
			if [ "$laststatus" != 0 ]; then  
				if [ "$repetition" -eq $verifyrepetitions ] ; then 
					#bluetooth device left
					notify "All specified light groups are off."
					refreshIPAddress
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
				#bluetooth device arrived, but a status has been determined
				notify "All specified light groups are turning on."
				refreshIPAddress
				sleep $defaultdelaybeforeon 
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
