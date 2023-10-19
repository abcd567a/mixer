# mixer & push

## (1) mixer
![mixer](https://github.com/abcd567a/mixer/assets/28452511/49fc6a84-9362-47dd-b1d2-ceeb73afecee)


The script below installs a software system which pulls data from various receivers and mixes these to display all aircraft on one Map.</br></br>
The combined data is also available at mixer's ports 40005 (beast), 40003 (sbs/basestation) and 40002 (raw/avr) and can be pushed to other sites by a suitable system of socat pipes naned here as **"push"** Script to do this is seperately installed (see below) </br></br>
This installation requires that dump1090-fa is already installed on the RPi / Computer on which this script is installed. </br></br>
The installation script given below creates 2nd copy of dump1090-fa as MIXER of beast data from various receivers on Local Network.</br></br>
The script also creates socat connections between Mixer and various receivers on Local Network. </br></br>

#### To install the mixer, copy-paste following bash script in PuTTY or terminal of RPi or Linux Computer:</br></br>
```
sudo bash -c "$(wget -O - https://github.com/abcd567a/mixer/raw/master/install-mixer.sh)"  
```


</br>

Mixer Map with mixed Data at: </br></br>
    IP-of-Pi/mixer/ </br>
    OR </br>
    IP-of-Pi:8585 </br>

</br>

Commands to restart mixer and socat pull pipes are:</br>
    sudo systemctl restart mixer  </br>
    sudo systemctl restart pull   </br>

All files located in folder /usr/share/mixer/.</br>

The config of mixer is in file /etc/default/mixer </br>

##### IP of your Receivers to be entered in file: </br>
`/usr/share/mixer/receivers.ip`</b>
one address per line.</br>
No blank space at top or between lines See example below:</br>

#### EXAMPLE of receiver IP entries user has to do in file receivers.ip: </br>

192.168.2.235 </br>
192.168.2.237 </br>
192.168.2.226 </br>
192.168.2.224 </br>
192.168.2.228 </br>
192.168.2.223 </br></br>

</br>

## (2) push
The **push** creares a system of socat connections from **mixer**'s output ports 40002 (avr), 40003 (msg), and 40005 (beast) to sites which accept TCP push connections.

#### To install the "push", copy-paste following bash script in PuTTY or terminal of your RPi or Linux Computer:</br></br>
```
sudo bash -c "$(wget -O - https://github.com/abcd567a/mixer/raw/master/install-push.sh)"

```
</br></br>
#### Following message is displayed on completion of installation:
open following file for editing:</br>
`sudo nano /usr/share/mixer/targets.ip ` </br>
in above file add IP's of your target sites in format</br>
[DATA_TYPE]:[IP_ADDRESS]:[PORT]</br>
One Site per line, like EXAMPLES below</br>

`msg:data.adsbhub.org:5001` </br>
`beast:94.130.23.233:5004` </br>
</br>
After adding target sites config and saving the file, restart socat by following command:</br>
sudo systemctl restart push </br>

</br></br>



 
