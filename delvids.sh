# Determine the memory remaining of the video folder.
partition_memory_free=$(df -B K --output=avail $1 | tail -n 1)
partition_memory_free=${partition_memory_free%?} # Removes the unit at the end
while (( $partition_memory_free < $2)); do
	delvid=$( ls $1 -1t | grep footage_ | tail -1 )
	echo "deleting ${delvid}"
	rm $1/${delvid}
	# Get the total spaced used on the partition the videos are being stored
	partition_memory_free=$(df -B K --output=avail $1 | tail -n 1)
	partition_memory_free=${partition_memory_free%?}
	echo $partition_memory_free
done
