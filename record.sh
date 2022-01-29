#! /bin/bash

# This script requires a lifepow4er UPS, and
# this package be installed:
# https://github.com/xorbit/LiFePO4wered-Pi

# This script records videos using libcamera
# module in segments. Before each recording,
# the following checks are made:
	# 1) Is there enough memory to record?
		# If not remove the oldest videos
		# until there is enough memory
	# 2) Is the battery charging?
		# If not, record the time and
		# set a shut off time. This time
		# is checked in the beginning of
		# each loop.
	# 3) Are we past our shutdown time?
		# If so, shut down the pi.

# Define paths
GPIO_PATH=/sys/class/gpio
WD=/home/pi/rpi_dashcam

# Define the amount of time the pi should stay on
# after UPS loses input power
BATTERY_POWER_SECONDS=3600

# Define how long each video should be in seconds
VIDEO_LENGTH=10

# Define the minimum free memory required before
# we start deleting old videos
MIN_KBYTES_TO_RECORD=3000000 # 3GB

# Since we just booted up, assume power is on.
power_off_flag=0

while :; do

	# Declare Date
	NOW=$( date '+%F_%H-%M-%S' )

	partition_memory_free=$(df -B K --output=avail ${WD} | tail -n 1)
	partition_memory_free=${partition_memory_free%?} # Removes the unit at the end

	# Spin off a child process to remove old videos if we don't have enough memory
	while (( $partition_memory_free < $MIN_KBYTES_TO_RECORD)); do

		rm $VIDEO_STORAGE_PATH/$( ls -1t | tail -1 )
		# Get the total spaced used on the partition the videos are being stored
		partition_memory_used=$(du -B M $VIDEO_STORAGE_PATH | cut -f 1 -d "   ")
		partition_memory_free=$(df -B K --output=avail /dev/sda1 | tail -n 1)
		partition_memory_free=${partition_memory_free%?} # Removes the unit at the end
	done

	# Get input voltage to the UPS. If it is near 0, assume car is off.
	VIN=$( lifepo4wered-cli get vin )

	# power_off_time should be the time we first recognized the power has
	# been shut off
	if (( $VIN < 200 )); then
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
	if (( $power_off_flag == 1 )) && (( $(date +%s) > $power_off_time )); then
		sudo shutdown -h now
	fi

	libcamera-vid -c config.txt -t $(( $current_video_length*1000 )) -o videos/footage_${NOW}.h264
done

