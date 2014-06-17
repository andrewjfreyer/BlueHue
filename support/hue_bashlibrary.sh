#!/bin/bash

# Hue BashLibrary (hue_bashlibrary.sh), version 1.0
# Written 2013 by Markus Proske, released under GNU GENERAL PUBLIC LICENSE v2, see LICENSE 
#
# Modified by Andrew J Freyer
#
# Google+: https://plus.google.com/+MarkusProske
# Github: https://github.com/markusproske/hue_bashlibrary
# ----------------------------------------------------------------------------------------


# Note: this library relies on curl to be installed on your system.
# Type which curl or curl --help in your Terminal to see if it is installed
# If not, install with sudo apt-get install curl 


# Variables
cmdname=''
lastlog=''
result_hue_is_on=-1
loglevel=0

#Group activation order
grouporder="4 1 6 8 7 3 2"

# Just simple logging helper implementing different loglevels
# $1...loglevel
# $2...output
function log() {	
	return;
}
# A little helper, depending on loglevel, it sets a gossip log OR just an error log in case of a request that did not result in an success
function log_error() {
	if (( $loglevel > 1 ))
	then
		if [[ "$1" == *\"error\"* ]]
		then
			log 4 "$1"
		fi
	else
		log 1 "$1"
	fi
}

#Get the state of the zero group
function hue_all_status () {
      curl -s $ip/api/$username/groups/0 | grep -ic "true"
}

# The _api_url helpers automatically start with http://yourIP/api/
# The helpers implement get/delete (one parameter: relative url) and put/post (two parameters: json-data and relative url)
# The current implementation relies on curl

# $1 = part of api url (starting after api/)
# $2 = force output regardless of log settings (for interactive functions like bridge_config)

function hue_get_apiurl() {
	log 1 "curl -s -H \"Content-Type: application/json\" \"http://$ip/api/$1\""
	output=$(curl -s -H "Content-Type: application/json" "http://$ip/api/$1")
	if [[ $2 == "print" ]]
	then
		printf "$output\n\n"
	else	
		log_error "$output"
	fi
}

# $1 = json parameters
# $2 = part of api url (starting after api/)
# $3 = force output regardless of log settings (for interactive functions)
function hue_put_apiurl() {
	log 1 "curl -s -X PUT -H \"Content-Type: application/json\" -d \"$1\" \"http://$ip/api/$2\" "
	output=$(curl -s -X PUT -H "Content-Type: application/json" -d "$1" "http://$ip/api/$2")
	if [[ $3 == "print" ]]
	then
		printf "$output\n\n"
	else	
		log_error "$output"
	fi
}

# $1 = json parameters
# $2 = part of api url (starting after api/)
# $3 = force output regardless of log settings (for interactive functions like bridge_link)
function hue_post_apiurl() {
	log 1 "curl -s -X POST -H \"Content-Type: application/json\" -d \"$1\" \"http://$ip/api/$2\" "
	output=$(curl -X POST -s -H "Content-Type: application/json" -d "$1" "http://$ip/api/$2")
	if [[ $3 == "print" ]]
	then
		printf "$output\n\n"
	else	
		log_error "$output"
	fi
}

# $1 = part of api url (starting after api/)
# $2 = force output regardless of log settings (for interactive functions like bridge_unlink)
function hue_delete_apiurl() {
	log 1 "curl -s -X DELETE -H \"Content-Type: application/json\" \"http://$ip/api/$1\" "
	output=$(curl -X DELETE -s -H "Content-Type: application/json" "http://$ip/api/$1")
	if [[ $2 == "print" ]]
	then
		printf "$output\n\n"
	else	
		log_error "$output"
	fi
}


# hue_get and hue_put are shortcuts that automatically start at http://yourIP/api/yourUSERNAME/

# $1 = part of api url (starting after $username/)
# $2 = force output regardless of log settings (for interactive functions like bridge_config)
function hue_get() {
	hue_get_apiurl "$username/$1" $2
}

# $1 = json parameters
# $2 = part of api url (starting after $username)
# $3 = force output regardless of log settings (for interactive functions)
function hue_put() {
	hue_put_apiurl "$1" "$username/$2" $3
}



# Only function that does not use one of the helpers - due to the need to parse the result
# Function hue_is_on: return 0, if light is off, return 1 if light is on
# $1 = light

# Example: hue_is_on 3

function hue_is_on() {
	log 1 "curl -s -H \"Content-Type: application/json\" \"http://$ip/api/$username/lights/$1\""
	output=$(curl -s -H "Content-Type: application/json" "http://$ip/api/$username/lights/$1")
	log_error "$output"

	if [[ "$output" == *\"on\":true* ]]
	then
		result_hue_is_on=1
	else
		result_hue_is_on=0
	fi
}



# BRIDGE FUNCTIONS
# ---------------------------------------------------------------------------------------
function bridge_discover {
	echo "Querying www.meethue.com/api/nupnp..."
	curl www.meethue.com/api/nupnp
	echo
}

function bridge_link {
	echo "1. Press the link button on your hue bridge."
	read -p "2. Press [Y|y] to link with your hue bridge: " -n 1 -r
	echo
	
	if [[ $REPLY =~ ^[Yy]$ ]] 
	then
		printf "Trying to establish link with your hue bridge (username: $username)...\n\n"
		
		hue_post_apiurl "{\"devicetype\":\"$devicetype\",\"username\":\"$username\"}" "" "print"
	else
		printf "Aborted.\n"
	fi
}

function bridge_unlink {
	read -p "Do you really want to unlink from your bridge? Press [Y|y] to continue: " -n 1 -r
	echo
	
	if [[ $REPLY =~ ^[Yy]$ ]] 
	then
		printf "Trying to unlink user $username from hue bridge...\n\n"

		hue_delete_apiurl "$username/config/whiteliste/$username" "print"
	else
		printf "Aborted.\n"
	fi
}

function bridge_config {
	printf "Current configuration of hue bridge $ip\n\n"
	hue_get "config" "print"
}



# INDIVIDUAL LIGHTS
# ---------------------------------------------------------------------------------------

# Function hue_getstate: fetch the state of a specific light
# $1 = light

# Examples: hue_getstate 3

function hue_getstate() {
	hue_get "lights/$1"
}


# Function hue_onoff: turns light(s) on or off, when turned on, light has its previous state
# $1 = on or off (remapped to true or false)
# $2..$x = light(s)
# Examples: hue_onoff "on" 1 or hue_onoff "off" 3 4 6

function hue_onoff() {
	# allow on/true and off/false as parameters
	state=$1
	if [[ $1 == "on" || $1 == "true" ]]
	then
		state="true"
	elif [[ $1 == "off" || $1 == "false" ]]
	then
		state="false"
	fi
	
	# process all lights
	for i in ${@:2}
	do
	    hue_put "{ \"on\": $state }" "lights/$i/state"
	done
}

# Function hue_allof: turn all lights off (group 0)

function hue_alloff {
	#30 seconds to turn off
	for i in $grouporder
	do
		hue_put "{ \"on\": false, \"transitiontime\": 20 }" "groups/$i/action"
		sleep 0.77
	done
}

# Function hue_allof: turn all lights on (group 0)

function hue_allon {
	if [ ! -z $1 ] && [ ! -z $2 ] && [ ! -z $3 ] && [ ! -z $4 ]; then 
		for i in $grouporder
		do
 			hue_put "{ \"on\": true, \"hue\": $1, \"sat\": $2, \"bri\": $3, \"transitiontime\": $4 }" "groups/$i/action"
 			sleep 0.9
 		done 
 	else 
 		hue_put "{ \"on\": true }" "groups/0/action"
 	fi	
}

# Function hue_allof: turn all lights on (group 0)


function hue_allon_custom () {

	bri=0 #0 - 255
	hue=0 #0 - 65535
	sat=0 #0 - 255
    transition=12 #in 1/10 seconds

	hour=$(date "+%H")

	if ((4<=hour && hour<=6)); then
		bri=255
		hue=46920
		sat=20
	elif ((6<=hour && hour<=10)); then
		bri=255
		hue=65535
		sat=20
	elif ((10<=hour && hour<=13)); then
		bri=240
		hue=0
		sat=10
	elif ((13<=hour && hour<=16)); then
		bri=255
		hue=46920
		sat=20
	elif ((16<=hour && hour<=21)); then
	    bri=240
		hue=46920
		sat=30
	elif ((21<=hour && hour<=23)); then
		bri=160
		hue=46920
		sat=40
	elif ((0<=hour && hour<=4)); then
		bri=120
		hue=46920
		sat=50
	else
		#catchall
		bri=230
		hue=46920
		sat=50
	fi

	#by default all lights will be turned on or off (i.e., group0)
	hue_allon $hue $sat $bri $transition
}


# Function hue_on_hue_sat_brightness: turns light(s) on with defined starting values (hue/sat/bri)
# $1 = hue value (0-65535)
# $2 = saturation value (0-255)
# $3 = brightness value (0-255)
# $4..$x = light(s)
# Examples: hue_on_hue_sat_brightness 25500 255 255 1 or hue_on_hue_sat_brightness 65535 100 200 3 4 6

function hue_on_hue_sat_brightness() {
	# process all lights
	for i in ${@:4}
	do
	    hue_put "{ \"on\": true, \"hue\": $1, \"sat\": $2, \"bri\": $3 }" "lights/$i/state"
	done
}


# Function hue_on_mired: turns light(s) on with defined starting value (mired)
# $1 = mired value (153 (6500K) to 500 (2000K)).
# $2 = brightness value (0-255)
# $3..$x = light(s)
# Examples: hue_on_mired 153 1 or hue_on_mired 500 3 4 6

function hue_on_mired_brightness() {
	# process all lights
	for i in ${@:3}
	do
		hue_put "{ \"on\": true, \"ct\": $1, \"bri\": $2 }" "lights/$i/state"
	done
}


# Function hue_setstate_brightness: set the brightness of one or more lights
# Range of brightness: 0 to 255  (0 is not off!)
# Remember: this fails, if the light is not turned on!
# $1 = brightness value
# $2..$x = light(s)
# Examples: hue_setstate_brightness 200 3 or hue_setstate_mired 200 3 4 7

function hue_setstate_brightness() {
	# process all lights
	for i in ${@:2}
	do
		hue_put "{ \"bri\": $1 }" "lights/$i/state"
	done
}


# Function hue_setstate_hue_sat: set the hue and saturation of one or more lights
# Range of hue: 0 and 65535. Both 0 and 65535 are red, 25500 is green and 46920 is blue.
# Range of saturation: 0 to 255  (0 is white)
# Remember: this fails, if the light is not turned on!
# $1 = hue value
# $2 = saturation value
# $3..$x = light(s)
# Examples: hue_setstate_hue_sat 65535 200 3 or hue_setstate_hue_sat 46920 200 3 4 7

function hue_setstate_hue_sat() {
	# process all lights
	for i in ${@:3}
	do
		hue_put "{ \"hue\": $1, \"sat\": $2 }" "lights/$i/state"
	done
}


# Function hue_setstate_mired: set the mired value of one or more lights
# Range of hue bulbs: 153 (6500K) to 500 (2000K).
# Remember: this fails, if the light is not turned on!
# $1 = mired value for color temperature
# $2..$x = light(s)
# Examples: hue_setstate_mired 300 3 or hue_setstate_mired 300 3 4 7

function hue_setstate_mired() {
	# process all lights
	for i in ${@:2}
	do
		hue_put "{ \"ct\": $1 }" "lights/$i/state"
	done
}


# Function hue_alert: flash light(s)
# $1 on | off | single
# $2..$x = light(s)
# Examples: hue_alert on 3 or hue_alert off 3 or hue_alert single 3 4 7
function hue_alert() {
	
	if [[ "$1" == "on" ]]
	then
	  param="lselect"
	else
		if [[ "$1" == "off" ]]
		then
			param="none"
		else
			param="select"
		fi
	fi
	
	# process all lights
	for i in ${@:2}
	do
		hue_put "{ \"alert\": \"$param\" }" "lights/$i/state"
	done
}
