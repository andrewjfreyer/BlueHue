BlueHue
=======

Bluetooth Proximity Switch for Activiating [Philips Hue Lights](http://meethue.com/)

* Designed around [hcitool](http://linuxcommand.org/man_pages/hcitool1.html)
* Designed for [Raspberry Pi](http://www.raspberrypi.org/) with a cheap [Bluetooth Dongle](http://www.amazon.com/SANOXY%C2%AE-Bluetooth-Wireless-Adapter-eMachine/dp/B003VWU79I/ref=pd_sim_pc_1?ie=UTF8&refRID=16KWQH2VYRTN82GTNS70). 
* Does not re-set light state/color changes made with App until bluetooth proximity state changes
* Bluetooth queries are efficient so as to not impact portable device battery

<h2>TL;DR</h2>

Turn [Philips Hue lights](http://www.meethue.com) on when upon arriving home and turn Hue lights off upon leaving without the delays of IFTTT or inaccuracies and battery drain associated with GeoFencing via the [Philips Hue app](https://itunes.apple.com/us/app/philips-hue/id557206189?mt=8). 

<h2>Summary</h2>

  BlueHue will query a previously-connected bluetooth device (*e.g.*, cell phone) for it's device name. If the device name is correct, BlueHue determines that the Bluetooth Device has 'arrived' and lights will be turned on. 

  After the Bluetooth Device is 'arrived', name queries preferrably reduce in frequency to not impact the Bluetooth Device battery. For example, the name may be queried once every 30 seconds or so.

  Later, when the Bluetooth Device leaves and is no longer reachable, BlueHue enters a verification state that will ping several times in a row for the Bluetooth Device. If the device is not found, BlueHue determines that the Bluetooth Device has 'left' and lights will be turned off. 

  BlueHue remembers its last state and only changes light state if the Bluetooth Device state (*e.g.*, left or arrived) changes. This way, if the light state is changed via the app (*e.g.*, turn off lights before going to bed), the lights state will not change until the Bluetooth Device state changes. 

<h2>Installation Instructions (Debian):</h2>

1. Install Bluetooth/Bluez
  
  `sudo apt-get install bluetooth bluez-utils blueman`
 
2. Discover mac address of Portable Bluetooth Device (*Note:* skip to 3 if MAC is known)
  
  `hcitool scan`

3. Connect the Portable Bluetooth Device to the server running BlueHue, choosing a pin number:

    `sudo bluetooth-agent {PIN NUMBER} {MAC ADDRESS}`

4. Add init.d

  `sudo echo “bash /home/pi/hue/blue_hue.sh true &” > /etc/init.d/bluehue`
  
  `sudo chmod 755 /etc/init.d/bluehue`
  
  `sudo update-rc.d bluehue defaults`
  
5. Reboot or Launch

  `sudo /etc/init.d/bluehue`



