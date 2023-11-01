# Mixer & Pusher

# (1) Mixer
![mixer](https://github.com/abcd567a/mixer/assets/28452511/49fc6a84-9362-47dd-b1d2-ceeb73afecee)


The script below installs a software system which pulls data from various receivers and mixes these to display all aircraft on one Map.</br></br>
The combined data is also available at mixer's ports 40005 (beast), 40003 (sbs/basestation) and 40002 (raw/avr) and can be pushed to other sites by a suitable system of socat pipes naned here as **"push"** Script to do this is seperately installed (see below) </br></br>
**NOTE-1: This installation requires that dump1090-fa is already installed on the RPi / Computer on which this script is installed.** If dump1090-fa is not already installed, please _FIRST_ install dump1090-fa, then after that run the mixer install script</br></br>
**NOTE-2: The installation script given below will in no way modify or disturb dump1090-fa.** It will creates 2nd copy of dump1090-fa with name **mixer**, and configure this copy (i.e. mixer) with setting `RECEIVER=none` (to run in `--net-only` mode), so that it does _NOT_ grab the dongle. The script also changes port numbers of `mixer` to prevent clash between `mixer` and `dump1090-fa` over use of ports. The `mixer` acts as mixer of beast data from various receivers on Local Network.</br></br>
The script also creates socat connections between Mixer and various receivers on Local Network. </br></br>

**To install the mixer, copy-paste following bash script in PuTTY or terminal of RPi or Linux Computer:** </br></br>
```
sudo bash -c "$(wget -O - https://github.com/abcd567a/mixer/raw/master/install-mixer.sh)"  
```


</br>

Mixer Map with mixed Data at: </br></br>
    IP-of-Pi/mixer/ </br>
    OR </br>
    IP-of-Pi:8585 </br>

</br>

**EXAMPLE of receiver IP entries you have to do in file `/usr/share/mixer/receivers.ip` :** </br>
**(one address per line)** </br>
`192.168.2.235` </br>
`192.168.2.237` </br>
`192.168.2.226` </br>
`192.168.2.224` </br>
`192.168.2.228` </br>
`192.168.2.223` </br>


**Commands to restart mixer and pull connections to receivers:**:</br>
    `sudo systemctl restart mixer `  </br></br>
  
**Command to list the connections of mixer to receivers:** </br>
`sudo systemctl status mixer`  </br></br>
Output of above command will list as follows: </br>
`Created pull@192.168.2.235` </br>
`Created pull@192.168.2.237` </br>
`Created pull@192.168.2.226` </br>

    
**Status of connection to any receiver:** </br>
`sudo systemctl status pull@ip-of-receiver ` </br>
**Examples:** </br>
`sudo systemctl status pull@192.168.0.123 ` </br>
`sudo systemctl status pull@192.168.0.34 ` </br>
    
All files located in folder `/usr/share/mixer/` </br>

The config of mixer is in file `/etc/default/mixer ` </br>

</br></br>

# (2) Pusher
The **pusher** creares a system of socat connections from **mixer**'s output ports 40002 (avr), 40003 (msg), and 40005 (beast) to sites which accept TCP push connections.

**To install the "pusher", copy-paste following bash script in PuTTY or terminal of your RPi or Linux Computer:**</br></br>
```
sudo bash -c "$(wget -O - https://github.com/abcd567a/mixer/raw/master/install-pusher.sh)"

```

**Following message is displayed on completion of installation:**
open following file for editing:</br>
`sudo nano /usr/share/mixer/targets.ip ` </br>
in above file add IP's of your target sites in format</br>
[DATA_TYPE]:[IP_ADDRESS]:[PORT]</br>
One Site per line, like EXAMPLE below</br>
`beast:feed.adsb.fi:30004` </br>
`msg:data.adsbhub.org:5001` </br>
`avr:94.130.23.233:5003` </br>
</br>
After adding target sites data type, IP & port, and saving the file, restart pusher by following command:</br>
`sudo systemctl restart pusher ` </br>

**Commands to restart push connections to targets:**:</br>
   `sudo systemctl restart pusher ` </br>

**Command to list the connections of mixer to targets:** </br>
`sudo systemctl status pusher`  </br></br>
Output of above command will list as following EXAMPLE: </br>
`Created push@feed1.adsbexchange.com` </br>
`Created push@feed.adsb.fi` </br>
`Created push@data.adsbhub.org` </br>

    
**Status of connection to any target:** </br>
`sudo systemctl status push@ip-of-target ` </br>
**EXAMPLES:** </br>
`sudo systemctl status push@feed1.adsbexchange.com ` </br>
`sudo systemctl status push@feed.adsb.fi ` </br>
`sudo systemctl status push@data.adsbhub.org` </br>   

**All files located in folder `/usr/share/pusher/`** </br>

</br></br>

</br></br>



 
