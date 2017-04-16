
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
# BASH API / NOTIFICATION API INCLUDE
# ----------------------------------------------------------------------------------------
Version=3.1.21

#find the support directory
support_directory="/home/pi/hue/support"
main_directory="/home/pi/hue"

#mosquitto 
topicpath="bluehue/presence" 

#source the support files
source "$support_directory/hue_bashlibrary.sh"
source "$support_directory/credentials_api"

#if and only if we have a notification system enabled
NOTIFICATIONSOURCE="$support_directory/notification_controller.sh" ; [ -f $NOTIFICATIONSOURCE ] && source $NOTIFICATIONSOURCE

# ----------------------------------------------------------------------------------------
# Set Program Variables
# ----------------------------------------------------------------------------------------

awayIterationMax=3 				#interations of 'away' mode after which light status is checked
delaywhilepresent=80 			#higher means slower turn off when leaving
delaywhileabsent=6 				#higher means slower recognition when turning on 
delaywhileverify=3 				#higher means slower verification of absence times
defaultdelaybeforeon=0			#higher means slower turn on
delaybetweenscan=3				#advised for bluetooth hardware 
verifyrepetitions=3 			#lower means more false rejection 
ip=0.0.0.0 						#IP address filler


#fill mac address array
IFS=$'\n' read -d '' -r -a macaddress < "$support_directory/credentials_user"

#load the defaults, if the user wants to specify their own 
CONFIGSOURCE=$main_directory/configuration ; [ -f $CONFIGSOURCE ] && source $CONFIGSOURCE

# ----------------------------------------------------------------------------------------
# Credential Information Verification
# ----------------------------------------------------------------------------------------

if [ -z "$devicetype" ] ||  [ -z "$username" ] || [ -z "$macaddress" ]; then 
	echo "error: please supply credentials; at least one credential is missing"
	exit 127
fi

# ----------------------------------------------------------------------------------------
# PAIR A NEW USER
# ----------------------------------------------------------------------------------------

function addNewUserToBluetooth () {
	#if there are $1 arguments, then use that as the search string 

	#need to check if sudo
	if [ "$(whoami)" != "root" ]; then 
		echo "Error: need to run as root."
		exit 1
	fi 

	#get the addresss
	bluetooth_dongle_address=$(hciconfig info | grep -Eo "[0-9A-F:]{17}")

	#is this dongle installed?
	if [ -d "/var/lib/bluetooth/$bluetooth_dongle_address" ]; then 
		echo "hci0 is $bluetooth_dongle_address"
	else
		echo "Error: No bluetooth dongle found."
		exit 1
	fi 

	#scan keyword
	keyword="iphone"

	if [ "$1" != "" ]; then 
		echo "Using keyword: $response"
		keyword="$1"
	else
		echo "Using keyword: iphone"
	fi 

	#scanning for the bluetooth device 
	scanresults=$(hcitool scan)

	#scan for name
	macaddress_new=$(echo "$scanresults" | grep -i "$keyword" | grep -Eo "[0-9A-F:]{17}")

	#if nothing found; exit
	if [ -z "$macaddress_new" ]; then 
		echo "No devices found."
		notify "No new bluetooth devices matching '$keyword' were found."
		return 0
	fi

	#need to verify that we are not already connected
	list_of_devices=$(sudo bluez-test-device list)

	if [ $(echo "$list_of_devices" | grep -ioc "$macaddress_new" ) -gt 0 ]; then 
		#device is already paired; get the pre-existing pin number
		PINCODE=$(cat "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes" | grep "$macaddress_new" | awk '{print $2}')
		echo " --> Disconnecting and forgetting $macaddress_new"
		errors=$(sudo bluez-test-device disconnect "$macaddress_new" 2>&1 1>/dev/null)
		errors=$(sudo bluez-test-device remove "$macaddress_new" 2>&1 1>/dev/null)

				#remove the device here
		echo " --> Removeing PIN $PINCODE from database."

		#clear from pincodes database
		cat "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes" | grep -v "$macaddress_new" > "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes"

		#clear from internal database
		cat "$support_directory/credentials_user" | grep -v "$macaddress_new" > "$support_directory/credentials_user"

	fi 

	#does the pin file exist?
	if [ ! -f "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes" ]; then 
		#create the file if needed
		echo "Creating new pincodes file."
		echo "#created by BlueHue - Andrew J Freyer" >> "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes"
	fi 

	#get a random four-digit pin number
	PIN=$(shuf -i 1000-9999 -n 1)

	#get the pin number set `
	hciconfig hci0 name "BlueHueProximity-$PIN"

	#does the path exist?
	if [ -d "/var/lib/bluetooth/$bluetooth_dongle_address" ]; then 
		#should test here for a big problem 
		echo "$macaddress_new $PIN" >> "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes"

		#add to database
		echo "$macaddress_new" >> "$support_directory/credentials_user"
	fi 

	#if we are here, then we can finally pair!
	hciconfig hci0 sspmode 0

	#pair
	bluetooth-agent "$PIN" "$macaddress_new"

	#list the avilable devices
	sudo bluez-test-device list

	#verify 
	new_username=$(hcitool name "$macaddress_new")

	#try to get the name
	if [ ! -z  $"new_username" ]; then 
		echo "Success!"
		#verify that we have found a new device
		notify "Note: $new_username at $macaddress_new."
	else
		notify "Note: failed to add $macaddress_new."
	fi 

	return 0
}


# ----------------------------------------------------------------------------------------
# GET THE IP OF THE BRIDGE
# ----------------------------------------------------------------------------------------

function refreshHueHubIPAddress () {
	ip=$(cat "$support_directory/hue_ip")
	verifybridge=$(curl -m 1 -s "$ip/api" | grep -c "not available for resource")

	#if we don't have an IP address from the cache or the bridge isn't responding, then 
	#we grab the IP address from the UPnP json sent from the bridge with remote access
	#enabled. 
	if [ -z "$ipaddress" ] || [ "$verifybridge" != "1" ]; then 
		ip=$(curl -s -L http://www.meethue.com/api/nupnp | grep -ioE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
		echo "$ip" > "$support_directory/hue_ip"
	fi
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
# Scan script
# ----------------------------------------------------------------------------------------

function scan () {
	if [ ! -z "$1" ]; then 
		echo $(hcitool name "$1" 2>&1 | grep -v 'not available')
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
	echo "	-p|--pair 	pair with new device"
	echo "\n"
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
		-p|--pair )
			addNewUserToBluetooth $2
			echo "Exiting."
			exit 1
		;;
	esac

fi 

# ----------------------------------------------------------------------------------------
# Prepare for Main Loop
# ----------------------------------------------------------------------------------------

#make sure that we have the most recent IP address of the Hue Bridge
refreshHueHubIPAddress

#set default variables; this variable is reset during the operation loop; just a placeholder
defaultwait=0

# ----------------------------------------------------------------------------------------
# Preliminary Notifications
# ----------------------------------------------------------------------------------------

#Number of clients that are monitored
numberofclients=$((${#macaddress[@]}))

#notify the current state along with 
notify "BlueHue (v. $Version) started."

#mqtt notification
/usr/bin/mosquitto_pub -t $topicpath -m "{status: true, version: $Version}"


# ----------------------------------------------------------------------------------------
# Set Main Program Loop
# ----------------------------------------------------------------------------------------

#status array
userStatus=()
countPresent=0

#begin the operational loop
while (true); do	

	#--------------------------------------
	#	UPDATE STATUS OF ALL USERS
	#--------------------------------------
	for index in "${!macaddress[@]}"
	do
		#cache bluetooth results 
		nameScanResult=""

		#obtain individual address
		searchdeviceaddress="${macaddress[$index]}"

		#obtain results and append each to the same
		nameScanResult=$(scan $searchdeviceaddress)
		
		#this device name is present
		if [ "$nameScanResult" != "" ]; then

			#this user's status changed
			if [ "${userStatus[$index]}" != "1" ]; then 
				#if at least one device was found continue

				# 2 = status just changed to present
				# 1 = status already present

				#only alert the first tiem
				if [ "${userStatus[$index]}" != "2" ]; then 
					/usr/bin/mosquitto_pub -t $topicpath -m "{status: true, user:\"$searchdeviceaddress\",present:\"true\",name:\"$nameScanResult\"}"
					userStatus[$index]="2"
					countPresent=$((countPresent+1))
				else
					userStatus[$index]="1"
				fi 
			fi 

			#continue with scan list
			sleep $delaybetweenscan

		else

				#this user's status changed
			if [ "${userStatus[$index]}" != "-1" ]; then 

				# -2 = status just changed to absent
				# -1 = status already absent

				#should verify absense
				for repetition in $(seq 1 $verifyrepetitions); 
				do 
					#perform scan
					nameScanResultRepeat=$(scan $searchdeviceaddress)

					#checkstan
					if [ "$nameScanResultRepeat" != "" ]; then
						#we know that we must have been at a previously-seen user status
						userStatus[$index]="1"
						break
					fi 
					#delay default time
					sleep $delaybetweenscan
				done

				#if still absent
				if [ "${userStatus[$index]}" != "-2" ]; then 
					countPresent=$((countPresent-1))
					/usr/bin/mosquitto_pub -t $topicpath -m "{status: true, user:\"$searchdeviceaddress\",present:\"false\"}"
				fi 
				#update status array
				userStatus[$index]="-2"
			fi 
			
			#continue with scan list
			sleep $delaybetweenscan
		fi
	done

	#-------------------------------------------------------
	# DETERMINE GLOBAL STATUS; VACANT OR OCCUPIED
	#-------------------------------------------------------
	echo "Present: $countPresent"

	#interate through status array to determine whether global status has changed
	for currentUserStatus in "${userStatus[@]}"
	do
		#this user is present now
		echo "$currentUserStatus"
	done

	continue

	#none of the bluetooth devices are present
	if [ "$atLeastOneUserStatusChanged" == "" ]; then
		if [ "$laststatus" != 0 ]; then  
			#publish status
			/usr/bin/mosquitto_pub -t $topicpath -m 'vacant'
			notify "Goodbye."

			#bluetooth device left
			refreshHueHubIPAddress
			hue_alloff
			laststatus=0
			defaultwait=$delaywhileabsent
			break

		else
			#bluetooth device remains absent
			defaultwait=$delaywhileabsent
			break
		fi 

		#verifiying 
		sleep "$delaywhileverify"

	elif [ "$atLeastOneUserStatusChanged" == "1" ]; then 
		if [ "$laststatus" != 1 ]; then  

			#publish to mqtt topic
			/usr/bin/mosquitto_pub -t $topicpath -m "occupied"
			notify "Welcome home!"

			#bluetooth device arrived, but a status has been determined
			refreshHueHubIPAddress
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

	#next operation
	sleep "$defaultwait"
done
