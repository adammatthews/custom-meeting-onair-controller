# Custom Meeting 'On Air' Light for macOS

Custom meeting 'On Air' light for Mac using OverSight, IFTTT and TP Link Tapo Light Strip

Script to be used with OverSight (https://objective-see.org/products/oversight.html) to control a Tapo Light Strip via IFTTT Webhooks. This also sends a message to an InfluxDB Bucket for a Grafana Dashboard.

## High Level Overview

A variable file is used to monitor the state of the camera and microphone (.oversight_vars). When the Mic is detected on, OverSight calls this script with -device microphone -event on. 
This script then sets the variable in the file, and then runs logic to call a specific IFTTT webhook to turn on the light for Microphone. If Camera and Mic are both off, the Webhook for Off is triggered. 

There is logic to determine if you are on your home WiFi connection or not, so you're not triggering this while you're out of the house. 

IFTTT has 4 seperate webhook Applets:
 1) mic_light - This turns on the light, this is in a seperate flow due to order of execurion issues in IFTTT
 2) mic_on - This switches the light colour to yellow. 
 3) mic_off - Used to trigger a full switch off of the light strip
 4) camera_on - Switches the light strip to red. 

## Usage

In the script, update the following varibles: 

	checkWifi=1
	wifiList=("<<SSID1>>" "<<SSID2>>") # Enter a list of your home/location WiFi Network SSIDs
	
	useInflux=1 # Set to 0 to skip using InfluxDB. 
	## InfluxDB URL, Token and host name for the machine you want to use. 
	influx_url="http://<<influx_url>>:8086/api/v2/write?bucket=camera_use&precision=s&org=orgname"
	influx_token="<<influx_bucket_token>>"
	influx_computer_host="<<name>>"

If you dont want to use InfluxDB, set useInflux to 0. 

Put the file in a location, and provide the script location within the OverSight app, under "Action", "Execute". Click to enable Pass Arguements. 


## Links

https://github.com/objective-see/OverSight
https://objective-see.org/products/oversight.html
https://www.tp-link.com/uk/home-networking/smart-bulb/tapo-l900-5/
https://ifttt.com/explore
