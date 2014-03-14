#!/bin/bash
# ----------------------------------------------------------------------------------------
# VERSION INFORMATION
# ----------------------------------------------------------------------------------------

# Written by Andrew J Freyer
# Version 1.5

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

delaywhilepresent=60 		#higher means slower turn off when leaving
delaywhilepresentrssi=5 	#higher means slower recognition of position changes
delaywhileabsent=10  		#higher means slower recognition when turning on 
delaywhileverify=5 			#higher means slower verification of absence times
delayafterconnection=15 
defaultwait=20
verifyrepetitions=10 	#lower means more false rejection 
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
# Enter RSSI Monitor Mode : Connected
# ----------------------------------------------------------------------------------------


function rssimonitor () {

	#check for root
	if [[ $UID -ne 0 ]]; then
		return
	fi

	#Internal Connection status
	bluetoothconnected=0
	rssi=0
	rssilast=1

	#motion prediction
	lastchange=$(date +%s)

	#Command loop:
	while [ 1 ];  do
		#if disconnected, attempt to connect & verify status
		if [ $bluetoothconnected = "0" ]; then
		    rfcomm release $macaddress
		    rfcomm connect 0 $macaddress 1 2>&1 > /dev/null &
		    bluetoothconnected=1 	#presumption
		    sleep $delayafterconnection
		    continue
		fi 

		#should be connected here
		rssiresult=$(hcitool rssi $macaddress)
		bluetoothconnected=$(echo $rssiresult | grep -c "RSSI return value")

		rssilast=$(echo "$rssi")
		rssi=$(echo $rssiresult | sed 's/RSSI return value: //g')

		#If still not connected
        if [ $bluetoothconnected -eq 0 ]; then
		    rfcomm release $macaddress
            break #Bluetooth has disconnected; re-verify in previous loop
        fi

        #various commands based on RSSI ranges
		if [ $bluetoothconnected = "1" ]; then

			if [ $rssi -eq $rssilast ] ; then
				#very close within 0-10 feet line of sight
				sleep $delaywhilepresentrssi
				continue
			else
				thischange=$(date +%s)
				timedifference=$((thischange-lastchange))
				rssidifference=$((rssi-rssilast))

				if [ $rssidifference -gt 2 ]; then 
					notify "Time since: $timedifference $rssidifference"
					lastchange=$(date +%s)
	
					if [ $rssi -gt $rssilast ]; then
						notify "Bluetooth Proximity: ~ Further Away"
					
					elif [ $rssi -lt $rssilast ]; then
						notify "Bluetooth Proximity: ~ Closer"
					fi
				fi 
			fi
		fi

		sleep $delaywhilepresentrssi

	done			
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
				rssimonitor $2
			else
				#bluetooth device remains present.
				defaultwait=$delaywhilepresent

				#missed the connection before leaving, try again
				rssimonitor $2

			fi
			break
		else
			echo "Unknown state."
		fi
	done
	sleep "$defaultwait"
done
