#!/bin/bash

### 
# Script to be used with OverSight (https://objective-see.org/products/oversight.html) to control a Tapo Light Strip via IFTTT Webhooks. This also sends a message to an InfluxDB Bucket for a Grafana Dashboard.
#
# High Level: A variable file is used to monitor the state of the camera and microphone (.oversight_vars). When the Mic is detected on, OverSight calls this script with -device microphone -event on. 
# This script then sets the variable in the file, and then runs logic to call a specific IFTTT webhook to turn on the light for Microphone. If Camera and Mic are both off, the Webhook for Off is triggered. 
#
# There is logic to determine if you are on your home WiFi connection or not, so you're not triggering this while you're out of the house. 
#
# IFTTT has 4 seperate flows:
#  1) mic_light - This turns on the light, this is in a seperate flow due to order of execurion issues in IFTTT
#  2) mic_on - This switches the light colour to yellow. 
#  3) mic_off - Used to trigger a full switch off of the light strip
#  2) camera_on - Switches the light strip to red. 
#
# Usage:
# ./oversight.sh -device camera -event off 
# ./oversight.sh -device camera -event on 
# ./oversight.sh -device microphone -event off 
# ./oversight.sh -device microphone -event on 
#
# Author: Adam Matthews (@adampmatthews)
# Date: Jan 2023
###

### VARIABLES TO AMEND  ###
checkWifi=1
wifiList=("<<SSID1>>" "<<SSID2>>") # Enter a list of your home/location WiFi Network SSIDs

useInflux=1 # Set to 0 to skip using InfluxDB. 
## InfluxDB URL, Token and host name for the machine you want to use. 
influx_url="http://<<influx_url>>:8086/api/v2/write?bucket=camera_use&precision=s&org=orgname"
influx_token="<<influx_bucket_token>>"
influx_computer_host="<<name>>"

### End VARIABLES ###
yslog -s -l error "###   OverSight Log: Started"
syslog -s -l error "OverSight Log: File - $0"  

reldir="$( dirname -- "$0"; )"; #This handles the script being called from OverSight, getting to the right dir for the variables file. 
cd "$reldir";
directory="$( pwd; )";

params=$@

syslog -s -l error "OversSight Log: $params"

# #initial mic/camera status - keeps creation of the initial file tidy. 
mic_status=0
camera_status=0

oversight_var_camera="$PWD/.oversight_vars_camera" # File will be auto-created on first run. File created in same directory as script. 
oversight_var_mic="$PWD/.oversight_vars_mic" # File will be auto-created on first run. File created in same directory as script. 

source $oversight_var_mic 
source $oversight_var_camera 

# Parse the arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -device)
      device="$2"
      shift 2
      ;;
    -event)
      event="$2"
      shift 2
      ;;
    -process)
      process="$2"
      shift 2
      ;;
    *)
      echo "Error: invalid option $1"
      exit 1
      ;;
  esac
done

echo "Device: $device"
echo "Event: $event"
echo "Process: $process"

syslog -s -l error "OverSight Log: ${device}, ${event}, ${process}" 

# Track Event Type
if [[ $event == "on" ]];
  then
    event=1
  fi

if [[  $event == "off" ]];
  then
    event=0
  fi

time=$(date +"%s") # get timestamp for influxDB

# Get the process that called the event, if not present set to none
if [ -z "$process" ]; then
  processname="none"
else
  process_path=`ps awx | awk -v x=$process '$1 == x { print $5 }'`
  processname=`basename $process_path`
fi

#
## Deal with only doing this when on a certain Wifi Network - comment out to stop
#
if [[ checkWifi ]]; then
  wifi=`networksetup -getairportnetwork en0 | awk '{print $4}'` ## Get Wifi Network Name
  echo "Wifi SSID: $wifi"

  if [[ ! " ${wifiList[*]} " =~ " ${wifi} " ]]; then
      # whatever you want to do when array contains value
      echo "Wifi - You are AWAY!"
      syslog -s -l error "OverSight Log: You are not at home, exit"
      exit 0
      #Crash our script and STOP here, we're not at home! 
  fi

  if [[ " ${wifiList[*]} " =~ " ${wifi} " ]]; then
      # whatever you want to do when array contains value
      echo "Wifi - You are HOME!"
  fi
fi

## End Wifi Checks
#

## Send status info to influxdb
#
if [[ useInflux ]]; then  
  curl --location --request POST "$influx_url" \
    --header "Authorization: Token $influx_token" \
    --header 'Content-Type: text/plain' \
    --data-raw "$device,host=$influx_computer_host,process=$processname value=$event $time"

  syslog -s -l error "OverSight Log: Sent to Influx -- $device,host=$influx_computer_host,process=$processname value=$event $time" 
fi

## Logic for calculating the variables for tracking status

if [[ $device == "microphone" ]]; then
  if [[  $event == 1 ]]; then
    #Mic On
    mic_status=1
  else
    #Mic Off
    mic_status=0
  fi
  declare -p mic_status > $oversight_var_mic
  syslog -s -l error "OverSight Log: Mic Status: $mic_status;" 

fi

if [[ $device == "camera" ]]; then
  if [[  $event == 1 ]]; then
    #Camera On
    camera_status=1
  else
    #Camera Off
    camera_status=0
  fi
  declare -p  camera_status > $oversight_var_camera
  syslog -s -l error "OverSight Log: Camera Status: $camera_status;" 
fi

sleep 1 #Pause while both calls happen (if Mic and Camera change at once), then re-get the current states. 
source $oversight_var_mic #re-get the variables to make sure we have the latest statuses before making calls
source $oversight_var_camera #re-get the variables to make sure we have the latest statuses before making calls

syslog -s -l error "OverSight Log: Mic Status: $mic_status; Cam Status: $camera_status"

## logic for working with the Tapi Light via IFTTT Webhook Triggers
if [[  $mic_status == 1 ]]; then
  if [ $camera_status == 1 ]; then
    curl --location --request GET 'https://maker.ifttt.com/trigger/mic_on/with/key/<<YOUR_IFTTT_KEY>>'
    curl --location --request GET 'https://maker.ifttt.com/trigger/camera_on/with/key/<<YOUR_IFTTT_KEY>>'
    syslog -s -l error "OverSight Log: Camera and Mic On Call" 
  else
    curl --location --request GET 'https://maker.ifttt.com/trigger/mic_on/with/key/<<YOUR_IFTTT_KEY>>'
    curl --location --request GET 'https://maker.ifttt.com/trigger/mic_light/with/key/<<YOUR_IFTTT_KEY>>'
    syslog -s -l error "OverSight Log: Mic On Call" 
  fi
fi

if [[  $mic_status == 0 ]]; then
  if [ $camera_status == 1 ]; then #if the camera is still on, but the mic is off, keep the red light on.
    curl --location --request GET 'https://maker.ifttt.com/trigger/mic_light/with/key/<<YOUR_IFTTT_KEY>>'
    curl --location --request GET 'https://maker.ifttt.com/trigger/camera_on/with/key/<<YOUR_IFTTT_KEY>>'
    syslog -s -l error "OverSight Log: Camera On Call (as Mic is Off, Camera is on)" 
  else
    curl --location --request GET 'https://maker.ifttt.com/trigger/mic_off/with/key/<<YOUR_IFTTT_KEY>>'
    syslog -s -l error "OverSight Log: Mic off call as Mic is Off" 
  fi
fi