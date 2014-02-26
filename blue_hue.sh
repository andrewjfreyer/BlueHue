#!/bin/bash
# ----------------------------------------------------------------------------------------
# VERSION INFORMATION
# ----------------------------------------------------------------------------------------

# Written by Andrew J Freyer
# Version 1.2.005

# ----------------------------------------------------------------------------------------
# BASH API / NOTIFICATION API INCLUDE & VAR SETTING
# ----------------------------------------------------------------------------------------

source /home/pi/hue/support/hue_bashlibrary.sh
NOTIFICATIONSOURCE=/home/pi/hue/support/notification.sh ; [ -f $NOTIFICATIONSOURCE ] && source $NOTIFICATIONSOURCE

# ----------------------------------------------------------------------------------------
# Credential Information
# ----------------------------------------------------------------------------------------

credentials=$(cat /home/pi/hue/support/hue_credentials)
devicetype=$(echo "$credentials" | awk '{print $1}')							
username=$(echo "$credentials" | awk '{print $2}')
DefaultMacAddress=$(echo "$credentials" | awk '{print $3}')
DeviceName=$(echo "$credentials" | awk '{print $4}')

#Error; One or more credentials is not found
if [ -z $devicetype ] ||  [ -z $username ] || [ -z $DefaultMacAddress ] || [ -z $DeviceName ]; then 
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

DefaultWaitWhilePresent=60
DefaultWaitWhileAbsent=10
DefaultWaitWhileVerify=5
DefaultWait=20
DefaultRepeatSequence=7

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

function absent_delay () {
	hour=$(date "+%H")

	#tally the number of times an absent phone becomes arrives during the course of the day
	#in order to power down the interface if neccessary

	#count of delay for this hour
	if [ "$CurrentHour" == "$hour" ]; then 
		#should return the same delay
		echo "$CurrentCalendarWhileAbsent"
		return

	else
		#should check for new delay
		now_count=$(cat /home/pi/hue/support/hue_calendar | grep "$hour:" | awk -F ":" '{print $2}')
		total=$(cat /home/pi/hue/support/hue_calendar | grep "total:" | awk -F ":" '{print $2}')
		percent=$((100*now_count/total))

		if ((percent<=10 && percent<0)); then
			#Less than 10% of the time, we arrive home in this hour;
			#five times the delay
			CurrentCalendarWhileAbsent=$((DefaultWaitWhileAbsent*5)) 
		elif ((10<percent && percent<50)); then
			#less than 50% of the time, we're arriving now
			CurrentCalendarWhileAbsent=$((DefaultWaitWhileAbsent*3)) 
		elif ((49<percent)); then
			#more than 50% of the time, we're arriving now
			CurrentCalendarWhileAbsent=$DefaultWaitWhileAbsent
		else
			#never arrived during this hour; max delay
			CurrentCalendarWhileAbsent=$((DefaultWaitWhileAbsent*10)) 
		fi

		echo "$CurrentCalendarWhileAbsent"
		return
	fi
}

function update_calendar () {
	
	if [ ! -f /home/pi/hue/support/hue_calendar]; then 
		#load default if necessary
		seq 0 24 | sed 's/$/:0:0/g;s/24/total/g' > /home/pi/hue/support/hue_calendar
	fi 
	#update the arrival calendar for this hour
	current_calendar=$(cat /home/pi/hue/support/hue_calendar)
	old_count_arrive=$(echo "$current_calendar" | grep "$CurrentHour:"| awk -F ":" '{print $2}')
	old_count_depart=$(echo "$current_calendar" | grep "$CurrentHour:"| awk -F ":" '{print $3}')

	old_total_arrive=$(cat /home/pi/hue/support/hue_calendar | grep "total:" | awk -F ":" '{print $2}')
	old_total_depart=$(cat /home/pi/hue/support/hue_calendar | grep "total:" | awk -F ":" '{print $3}')

	new_total_arrive=$old_total_arrive
	new_count_arrive=$old_count_arrive
	new_count_depart=$old_count_depart

	if [ "$1" == "arrive" ]; then 
		#adjust only the arrivals 
		new_count_arrive=$((old_count+1))
		new_total_arrive=$((old_total+1))
	else
		#adjust only the departures
		new_count_depart=$((old_count+1))
		new_total_depart=$((old_total+1))
	fi

	percent_arrive=$((100*new_count_arrive/(new_total_arrive+1)))
	percent_depart=$((100*new_count_depart/(new_total_depart+1)))

	notify "You arrive this hour $percent_arrive% of the time and leave $percent_depart% of the time."
	#Create new file
	echo "$current_calendar" | sed 's/'$CurrentHour':'$old_count_arrive':'$old_count_depart'/'$CurrentHour':'$new_count_arrive':'$new_count_depart'/g;s/total:'$old_total_arrive':'$old_total_depart'/total:'$new_total_arrive':'$new_total_depart'/g' > /home/pi/hue/support/hue_calendar
}

# ----------------------------------------------------------------------------------------
# COLOR PER TIME OF DAY
# ----------------------------------------------------------------------------------------

function hue_allon_custom () {
	# Range of hue: 0 and 65535. Both 0 and 65535 are red, 25500 is green and 46920 is blue.

	bri=0 #0 - 255
	hue=0 #0 - 65535
	sat=0 #0 - 255
        transition=10

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
	    bri=190
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
		ScanResult=$(hcitool name "$DefaultMacAddress" 2>&1)
		
		iPhonePresent=$(echo "$ScanResult" | grep -ic "$DeviceName")

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
				DefaultWait=$(absent_delay)
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
