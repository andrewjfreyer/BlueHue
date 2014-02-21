#!/bin/bash

# ----------------------------------------------------------------------------------------
# VERSION INFORMATION
# ----------------------------------------------------------------------------------------

# Written by Andrew J Freyer
# Version 1.2.003

# ----------------------------------------------------------------------------------------
# Check Root
# ----------------------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
	echo "BlueHue: Must be a root user for setup" 2>&1
	exit 1
else
	echo "Running as root."
fi

# ----------------------------------------------------------------------------------------
# Scanning for Local Devices in Discoverable Mode & Automatically Joining
# ----------------------------------------------------------------------------------------

function discover () {
	#Replace with your device and username
	DeviceType="api"
	Username="andrewjfreyer"
	
	#Mac Addresse
	MacAddressesOfBluetoothDevicesNearby=$(hcitool scan | grep -ioE "[0-9]:[0-9]:[0-9]:[0-9]:[0-9]:[0-9]")

	# Iterate through search results
	if [ ! -z "$MacAddressesOfBluetoothDevicesNearby" ]; then 
		#separator
		IFS=$'\n'

		for address in $MacAddressesOfBluetoothDevicesNearby
		do
		        echo "Attempting to pair with: $address"
	        	PairResult=$(sudo bluetooth-agent 0000 $address 2>&1)

	        	if [ -z "$PairResult" ]; then 
	        		echo "Pairing failed for $address"
	        	else
	        		#Pairing succeeded; get name; not dealing with spaces, just take the first part of the name
       				DeviceName=$(hcitool name "$address" 2>&1 | awk -F " " '{print $1}')

	        		if [ ! -z "$DeviceName" ]; then 
	        			#Should add device to device list
	        			echo "$DeviceType $Username $address $DeviceName"
	        			break
	        		fi
	        	fi
		done
	fi

}

