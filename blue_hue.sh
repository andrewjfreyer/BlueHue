
#!/bin/bash

# ----------------------------------------------------------------------------------------
# GENERAL INFORMATION
# ----------------------------------------------------------------------------------------
#
# BlueHue - Bluetooth Proximity Switch for Hue Ligts
# Written by Andrew J Freyer
# GNU General Public License
#
# ----------------------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------
# Simple pair: 			sudo l2ping MAC (with device discoverable)
# Enable simple pair: 	sudo hciconfig hci0 sspmode 0 ; set pairing code; pair
# ----------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------
# BASH API / NOTIFICATION API INCLUDE
# ----------------------------------------------------------------------------------------
Version=2.14.7
source /home/pi/hue/support/hue_bashlibrary.sh
source /home/pi/hue/support/credentials
NOTIFICATIONSOURCE=/home/pi/hue/support/notification.sh ; [ -f $NOTIFICATIONSOURCE ] && source $NOTIFICATIONSOURCE

# ----------------------------------------------------------------------------------------
# Set Program Variables
# ----------------------------------------------------------------------------------------

awayIterationMax=5 				#interations of 'away' mode after which light status is checked
delaywhilepresent=80 			#higher means slower turn off when leaving
delaywhileabsent=6 				#higher means slower recognition when turning on 
delaywhileverify=3 				#higher means slower verification of absence times
defaultdelaybeforeon=0			#higher means slower turn on
delaybetweenscan=3				#advised for bluetooth hardware 
verifyrepetitions=3 			#lower means more false rejection 
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
		ip=$(curl -s -L http://www.meethue.com/api/nupnp | grep -ioE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
		echo "$ip" > /home/pi/hue/support/hue_ip
	fi
}

# ----------------------------------------------------------------------------------------
# GET THE COUNT(S) OF LIGHTS ON
# ----------------------------------------------------------------------------------------

function lightStatus () {
	#count the lights that are turned on to get the current status
	lightstatus=$(curl -s $ip/api/$username/ | grep -Eo "\"lights\".*?\"groups\"")
	countoflightson=$(echo "$lightstatus" | grep -ioc "\"on\":true")
	countoflights=$(echo "$lightstatus" | grep -io "\"name\":" | wc -l)

	#formatted as sentence; not parsed
	echo "$countoflightson light(s) ON and $((countoflights - countoflightson)) light(s) OFF"
}

# ----------------------------------------------------------------------------------------
# Notification Script... Should be modified for individual notifications
# ----------------------------------------------------------------------------------------

function notify () {
	if [ ! -z "$1" ]; then 
		[ -f $NOTIFICATIONSOURCE ] && notifyViaPushover "$1"
	fi
}

# ----------------------------------------------------------------------------------------
# Print Help
# ----------------------------------------------------------------------------------------

function help () {
	clear 

	#quick fake of a man page
	echo "NAME"
	echo "	blue_hue - bluetooth proximity for Philips Hue"
	echo "	v. $Version"
	echo "\n"
	echo "SYNOPSIS"
	echo "	blue_hue  [-v|--version] [-h|--help]"
	echo "\n"
	echo "DESCRIPTION"
	echo "	Control Philips Hue lights via bluetooth proximity of multiple devices"
	echo "\n"
	echo "OPTIONS"
	echo "	-v|--version 	print version information"
	echo "	-h|--help 	print this help file"
	echo "\n"
	echo "FILES"
	echo "	/support/credentials 	add Hue API and other information"
	echo "\n"
	echo "AUTHOR"
	echo "	Andrew J. Freyer - 2015 (https://github.com/andrewjfreyer/)"
	echo "\n"

	exit 1
}


# ----------------------------------------------------------------------------------------
# ARGV processing 
# ----------------------------------------------------------------------------------------

#argv updates
if [ ! -z "$1" ]; then 
	#very rudamentary process here, only limited support for input functions
	case "$1" in
		-v|--version )
			echo "$Version"
			exit 1
		;;
		-h|--help )
			help
			exit 1
		;;
	esac

fi 

# ----------------------------------------------------------------------------------------
# Prepare for Main Loop
# ----------------------------------------------------------------------------------------

#make sure that we have the most recent IP address of the Hue Bridge
refreshIPAddress

#set default variables; this variable is reset during the operation loop; just a placeholder
defaultwait=0

# ----------------------------------------------------------------------------------------
# Preliminary Notifications
# ----------------------------------------------------------------------------------------

statusOfLights=$(lightStatus)

#Number of clients that are monitored
numberofclients=$((${#macaddress[@]} + 1))

#notify the current state along with 
if [ "$countoflightson" != "0" ]; then
	notify "BlueHue Proximity (v. $Version) started; $statusOfLights on ($numberofclients clients)."
else
	notify "BlueHue Proximity (v. $Version) started with all light(s) off ($numberofclients clients)."
fi

# ----------------------------------------------------------------------------------------
# Set Main Program Loop
# ----------------------------------------------------------------------------------------

#prepare necessary variables
currentLightStatusString="$statusOfLights"

#status check iterator
statusCheckIterator=0

#begin the operational loop
while (true); do	

	#repeat for X times to verify that all bluetooth devices have left
	for repetition in $(seq 1 $verifyrepetitions); 
	do 
		#cache bluetooth results 
		bluetoothscanresults=""

		#searching from array-formatted credential file 
		for index in "${!macaddress[@]}"
		do
			#obtain individual address
			searchdeviceaddress="${macaddress[$index]}"

			#obtain results and append each to the same
			bluetoothscanresults="$bluetoothscanresults$(hcitool name "$searchdeviceaddress" 2>&1 | grep -v 'not available')"
			bluetoothdevicepresent=$(echo "$bluetoothscanresults" | grep -icE "[a-z0-9]")
			
			if [ "$bluetoothscanresults" != "" ]; then
 				#if at least one device was found continue
 				break
 			else
 				#else, continue with scan list
				sleep $delaybetweenscan
 			fi
		done

		#none of the bluetooth devices are present
		if [ "$bluetoothscanresults" == "" ]; then
			if [ "$laststatus" != 0 ]; then  
				if [ "$repetition" -eq $verifyrepetitions ] ; then 
					#bluetooth device left
					notify "Goodbye."
					refreshIPAddress
					hue_alloff
					laststatus=0
					defaultwait=$delaywhileabsent
					break
				fi
			else

				#inject an option to search for lights changes
				if [ "$statusCheckIterator" -gt $awayIterationMax ] ; then 
					#get new light status
					newlightstatusstrings=$(lightStatus)

					echo "DEBUG: testing: $newlightstatusstrings"

					if [ "$currentLightStatusString" != "$newlightstatusstrings" ]; then 
						#reset the variable holder
						currentLightStatusString="$newlightstatusstrings"

						#notify
						notify "Light status changed to: $currentLightStatusString"
					fi

					#reset the counter
					statusCheckIterator=0
				
				else
					#iterate the counter
					statusCheckIterator=$((statusCheckIterator+1))
				fi

				#bluetooth device remains absent
				defaultwait=$delaywhileabsent
				break
			fi 
			sleep "$delaywhileverify"

		elif [ "$bluetoothdevicepresent" == "1" ]; then 
			if [ "$laststatus" != 1 ]; then  
				#bluetooth device arrived, but a status has been determined
				notify "Welcome home. ($bluetoothscanresults)"
				refreshIPAddress
				sleep $defaultdelaybeforeon 
				hue_allon_custom
				laststatus=1

				#reset to 0
				statusCheckIterator=0

			else
				#bluetooth device remains present.
				defaultwait=$delaywhilepresent
			fi
			break
		else
			echo "Unknown state."
		fi
	done

	#next operation
	sleep "$defaultwait"
done
