
#!/bin/bash

# ----------------------------------------------------------------------------------------
# GENERAL INFORMATION
# ----------------------------------------------------------------------------------------
#
# Blue_MQTT - Bluetooth Proximity 
# Written by Andrew J Freyer
# GNU General Public License
#
# ----------------------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------
# BASH API / NOTIFICATION API INCLUDE
# ----------------------------------------------------------------------------------------
Version=4.0.4

#find the support directory
support_directory="/home/pi/hue/support"
main_directory="/home/pi/hue"

#source the support files
source "$support_directory/credentials_mqtt"

#if and only if we have a notification system enabled
NOTIFICATIONSOURCE="$support_directory/notification_controller.sh" ; [ -f $NOTIFICATIONSOURCE ] && source $NOTIFICATIONSOURCE

# ----------------------------------------------------------------------------------------
# Set Program Variables
# ----------------------------------------------------------------------------------------

delaybetweenscan=10		#advised for bluetooth hardware 
verifyrepetitions=2 	#lower means more false rejection 


#fill mac address array
IFS=$'\n' read -d '' -r -a macaddress < "$support_directory/credentials_user"

#load the defaults, if the user wants to specify their own 
CONFIGSOURCE=$main_directory/configuration ; [ -f $CONFIGSOURCE ] && source $CONFIGSOURCE

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
	echo "	blue_mqtt - bluetooth proximity over MQTT"
	echo "	v. $Version"
	echo "\n"
	echo "SYNOPSIS"
	echo "	blue_mqtt  [-v|--version] [-h|--help]"
	echo "\n"
	echo "DESCRIPTION"
	echo "	Notify MQTT of bluetooth proximity of multiple devices"
	echo "\n"
	echo "OPTIONS"
	echo "	-v|--version 	print version information"
	echo "	-h|--help 	print this help file"
	echo "	-p|--pair 	pair with new device"
	echo "\n"
	echo "	/support/credentials 	other information"
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
# Preliminary Notifications
# ----------------------------------------------------------------------------------------

#Number of clients that are monitored
numberofclients=$((${#macaddress[@]}))

#notify the current state along with 
notify "BlueMQTT (v. $Version) started."

# ----------------------------------------------------------------------------------------
# Set Main Program Loop
# ----------------------------------------------------------------------------------------

#status
userStatus=()

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
		currentDeviceMAC="${macaddress[$index]}"

		#obtain results and append each to the same
		nameScanResult=$(scan $currentDeviceMAC)
		
		#this device name is present
		if [ "$nameScanResult" != "" ]; then

			/usr/bin/mosquitto_pub -h "$mqtt_address" -u "$mqtt_user" -P "$mqtt_password" -t "$mqtt_topicpath/$currentDeviceMAC" -m "100"

			#user status			
			userStatus[$index]="100"

			#continue with scan list
			sleep $delaybetweenscan

		else
			#user status			
			status="${userStatus[$index]}"

			if [ "$status" == "" ]; then 
				$status = "0"
			fi 

			#should verify absense
			for repetition in $(seq 1 $verifyrepetitions); 
			do 
				#get percentage
				percentage=$(( $status * ( $verifyrepetitions - $repetition) / $verifyrepetitions))

				#perform scan
				nameScanResultRepeat=$(scan $currentDeviceMAC)

				#checkstan
				if [ "$nameScanResultRepeat" != "" ]; then
					#we know that we must have been at a previously-seen user status

					/usr/bin/mosquitto_pub -h "$mqtt_address" -u "$mqtt_user" -P "$mqtt_password" -t "$mqtt_topicpath/$currentDeviceMAC" -m "100"

					userStatus[$index]="100"
					break
				fi 

				#update percentage
				userStatus[$index]="$percentage"

				#report confidence drop
				/usr/bin/mosquitto_pub -h "$mqtt_address" -u "$mqtt_user" -P "$mqtt_password" -t "$mqtt_topicpath/$currentDeviceMAC" -m "$percentage"

				#set to percentage
				userStatus[$index]="$percentage"

				#delay default time
				sleep $delaybetweenscan
			done

			if [ "${userStatus[$index]}" == "0" ]; then 
				/usr/bin/mosquitto_pub -h "$mqtt_address" -u "$mqtt_user" -P "$mqtt_password" -t "$mqtt_topicpath/$currentDeviceMAC" -m "0"
			fi

			#continue with scan list
			sleep $delaybetweenscan
		fi
	done

	#next operation
	sleep $delaybetweenscan
done
