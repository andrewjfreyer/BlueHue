BlueHue
=======

Bluetooth Proximity Switch for Activiating Hue Lights

* Designed around [hcitool](http://linuxcommand.org/man_pages/hcitool1.html)
* Does not re-set lighting changes made via app until bluetooth proximity state changes
* Bluetooth queries are efficient so as to not impact portable device battery

<h1>Instructions (Debian):</h1>

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



