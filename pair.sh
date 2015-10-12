
#!/bin/bash

# ----------------------------------------------------------------------------------------
# GENERAL INFORMATION - pairing
# ----------------------------------------------------------------------------------------
#
# Written by Andrew J Freyer
# GNU General Public License
#
# ----------------------------------------------------------------------------------------

echo "-- Blue Hue Proximity Pairing --"

#need to check if sudo
if [ "$(whoami)" != "root" ]; then 
	echo "Error: need to run as root."
	exit 1
fi 

clear

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

#now we scan 
read -p "Place the device in discovery mode" response

if [ "$response" != "" ]; then 
	#echo "Using keyword: $response"
	keyword="$response"
else
	#echo "Using keyword: iphone"
fi 

#scanning for the bluetooth device 
scanresults=$(hcitool scan)

#scan for name
macaddress=$(echo "$scanresults" | grep -i "$keyword" | grep -Eo "[0-9A-F:]{17}")

#verify
echo "Found: $macaddress"

#need to verify that we are not already connected
list_of_devices=$(sudo bluez-test-device list)

if [ $(echo "$list_of_devices" | grep -ioc "$macaddress" ) -gt 0 ]; then 
	#device is already paired; get the pre-existing pin number
	PINCODE=$(cat "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes" | grep "$macaddress" | awk '{print $2}')

	#confirm what we want to do...
	read -p "Mac address $macaddress already paired with $PINCODE. Remove and re-pair? (Y/N) " response

	case $response in
		[yY]*)
			#disconnect
			echo " --> Disconnecting and forgetting $macaddress"
			errors=$(sudo bluez-test-device disconnect "$macaddress" 2>&1 1>/dev/null)
			errors=$(sudo bluez-test-device remove "$macaddress" 2>&1 1>/dev/null)

			#remove the device here
			echo " --> Removeing PIN $PINCODE from database."
			cat "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes" | grep -v "$macaddress" > "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes"

			#confirm that we're done
			read -p " --> Forget 'BlueHueProximity-####' on your device." response
		;;
		[nN]*)
			echo "Exiting."
			exit 1
		;;
	esac
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
	echo "$macaddress $PIN" >> "/var/lib/bluetooth/$bluetooth_dongle_address/pincodes"
fi 

#if we are here, then we can finally pair!
hciconfig hci0 sspmode 0

#pair
bluetooth-agent "$PIN" "$macaddress"

#list the avilable devices
sudo bluez-test-device list

#try to get the name
if [ ! -z $(hcitool name "$macaddress") ]; then 
	echo "Success!"
fi 