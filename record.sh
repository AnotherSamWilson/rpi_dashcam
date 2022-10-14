#! /bin/bash

# This script requires a lifepow4er UPS, and
# this package be installed:
# https://github.com/xorbit/LiFePO4wered-Pi

# This script records videos using libcamera module in segments. Before each recording,
# the following checks are made:
	# 1) Is there enough memory to record?
		# If not remove the oldest videos until there is enough memory
	# 2) Is the battery charging?
		# If not, record the time and set a shut off time. This time
		# is checked in the beginning of each loop.
	# 3) Are we past our shutdown time?
		# If so, shut down the pi.


VIDEO_STORAGE_PATH=$1

# Define the amount of time the pi should stay on
# after UPS loses input power
BATTERY_POWER_SECONDS=$2

# Define how long each video should be in seconds
VIDEO_LENGTH=$3

# If our shutdown time is less than this many seconds
# in the future, don't bother recording a video.
MIN_VIDEO_LENGTH=5

# Define the minimum free memory required before
# we start deleting old videos
MIN_KBYTES_TO_RECORD=3000000 # 3GB


#################
# END USER VALUES

# Since we just booted up, assume power is on.
power_off_flag=0

# This auto boot setup will boot the pi if:
	# There is sufficient input voltage (VIN >= VIN_THRESHOLD)
	# There is sufficient battery voltage (VBAT >= VBAT_BOOT)
if (( $(lifepo4wered-cli get auto_boot) != 3 )); then
	lifepo4wered-cli set auto_boot 3
fi

# Start the main loop
while :; do

	# Declare Date
	NOW=$( date '+%F_%H-%M-%S' )

	# Script deletes videos in the background if they are too old
	./delvids.sh $VIDEO_STORAGE_PATH $MIN_KBYTES_TO_RECORD &

	# Get input voltage to the UPS. If it is near 0, assume car is off.
	VIN=$( lifepo4wered-cli get vin )
	VBAT=$( lifepo4wered-cli get vbat )

	# power_off_time should be the time we first recognized the power has been shut off
	if (( $VIN < 200 )); then
		echo "power off"
		if (( $VBAT < 3000 )); then
			echo "Battery voltage is low: " $VBAT ", shutting down"
			sudo shutdown -h now
		fi
		if (( power_off_flag == 0 )); then
			power_off_flag=1
			power_off_time=$(date +%s)+$BATTERY_POWER_SECONDS
		fi
		current_video_length=$(( ($power_off_time-$(date +%s)) < VIDEO_LENGTH ? ($power_off_time-$(date +%s)) : VIDEO_LENGTH ))
	else
		power_off_flag=0
		current_video_length=$VIDEO_LENGTH
	fi



	# If our power off flag = 1 and the required number of seconds has elapsed, shut down.
	if (( $power_off_flag == 1 )) && (( $(date +%s) >= $power_off_time-$MIN_VIDEO_LENGTH )); then
		sudo shutdown -h now
	fi

	# As of now libcamera-vid does not have native timestamp overlay. We save timestamps
	# in a separate folder and use mkvmerge to create a final .mkv file.
	echo "recording video of length" $current_video_length
	libcamera-vid -n -c config.txt -t $(( $current_video_length*1000 )) -o ${VIDEO_STORAGE_PATH}/footage_${NOW}.h264
done
