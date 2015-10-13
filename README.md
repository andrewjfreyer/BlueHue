BlueHue
=======

Bluetooth Proximity Switch for Activiating [Philips Hue Lights](http://meethue.com/)

* Designed around [hcitool](http://linuxcommand.org/man_pages/hcitool1.html)
* Designed for [Raspberry Pi](http://www.raspberrypi.org/) with a cheap [Bluetooth Dongle](http://www.amazon.com/SANOXY%C2%AE-Bluetooth-Wireless-Adapter-eMachine/dp/B003VWU79I/ref=pd_sim_pc_1?ie=UTF8&refRID=16KWQH2VYRTN82GTNS70). 
* Does not re-set light state/color changes made with App until bluetooth proximity state changes
* Bluetooth queries are efficient so as to not impact portable device battery
* Works with [PushOver](http://www.pushover.net) service for alerts & notifications

Based on a slightly modified [hue_bashlibrary](https://github.com/markusproske/hue_bashlibrary) by [markusproske](https://github.com/markusproske)

<h2>TL;DR</h2>

[![YouTube Video of Simulated Arrival](http://img.youtube.com/vi/JVYdRJQqmJA/0.jpg)](http://www.youtube.com/watch?v=JVYdRJQqmJA)

Turn [Philips Hue lights](http://www.meethue.com) on with a [Raspberry Pi](http://www.raspberrypi.org/) (or other server) upon arriving home and off upon leaving without the delays of IFTTT or inaccuracies and battery drain associated with geofencing via the [Philips Hue app](https://itunes.apple.com/us/app/philips-hue/id557206189?mt=8). 

<h2>Summary</h2>

  BlueHue will query a previously-connected bluetooth device (*e.g.*, cell phone) for it's device name. If the device name is correct, BlueHue determines that the Bluetooth Device has 'arrived' and lights will be turned on. 

  After the Bluetooth Device is 'arrived', name queries preferrably reduce in frequency to not impact the Bluetooth Device battery. For example, the name may be queried once every 30 seconds or so.

  Later, when the Bluetooth Device leaves and is no longer reachable, BlueHue enters a verification state that will ping several times in a row for the Bluetooth Device. If the device is not found, BlueHue determines that the Bluetooth Device has 'left' and lights will be turned off. 

  BlueHue remembers its last state and only changes light state if the Bluetooth Device state (*e.g.*, left or arrived) changes. This way, if the light state is changed via the app (*e.g.*, turn off lights before going to bed), the lights state will not change until the Bluetooth Device state changes. 

<h2>Installation Instructions (Debian):</h2>

1. Add user & connect to Philips Hue Bridge

   Instructions [here](http://developers.meethue.com/4_configurationapi.html#41_create_user).  Clip API is often the easiest way to send this first instruction:

  `http://<bridge ip address>/debug/clip.html`

2. Install Bluetooth/Bluez
  
  `sudo apt-get install bluetooth bluez-utils blueman`


3. Pair the bluetooth device. :

	Instructions: set the device to discoverable mode, then (optionally) set search string for device name (default is 'iphone'):

	`sudo bash blue_hue.sh -p|--pair [search]`

	A pairing request from "BlueHueProximity-####" will be made to the device where #### is the pin to enter. 


4. Add init.d

  `if [ "$1" == "start" ]; then bash /home/pi/hue/blue_hue.sh true & ;  fi`

  `sudo chmod 755 /etc/init.d/bluehue`
  
  `sudo update-rc.d bluehue defaults`
  
5. Add information to credentials and/or configuration file(s)


6. Reboot or Launch

  `sudo /etc/init.d/bluehue`







