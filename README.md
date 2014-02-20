BlueHue
=======

Bluetooth Proximity Switch for Activiating Hue Lights

* Designed around [hcitool](http://linuxcommand.org/man_pages/hcitool1.html)
* Does not re-set light state/color changes made with App until bluetooth proximity state changes
* Bluetooth queries are efficient so as to not impact portable device battery
* Designed for [Raspberry Pi](http://www.raspberrypi.org/) with a cheap [Bluetooth Dongle](http://www.amazon.com/SANOXY%C2%AE-Bluetooth-Wireless-Adapter-eMachine/dp/B003VWU79I/ref=pd_sim_pc_1?ie=UTF8&refRID=16KWQH2VYRTN82GTNS70). 

<h2>Installation Instructions (Debian):</h2>

1. Install Bluetooth/Bluez
  
  `sudo apt-get install bluetooth bluez-utils blueman`
 
2. Discover mac address of Portable Bluetooth Device (or skip to 3 if MAC is known)
  
  `hcitool scan`

3. Connect the Portable Bluetooth Device to the server running BlueHue, choosing a pin number:

    `sudo bluetooth-agent {PIN NUMBER} {MAC ADDRESS}`

4. Add init.d

  `sudo echo “bash /home/pi/hue/blue_hue.sh true &” > /etc/init.d/bluehue`
  
  `sudo chmod 755 /etc/init.d/bluehue`
  
  `sudo update-rc.d bluehue defaults`
  
5. Reboot or Launch

  `sudo /etc/init.d/bluehue`



