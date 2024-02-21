#!/bin/bash

# Set up variables
container=<container_name> # Replace with the actual container name
backupDirectory="/path/to/docker-backups" # Replace with the actual path
logFile="$backupDirectory/backup.log"
backupDate=$(date +'%Y-%m-%d_%H-%M')
startTime=$(date +%s)
maxBackups=2  # Maximum number of backups to keep

# Function to log datetime and status to the log file
log_to_file() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$logFile"
}

# Function to send notifications
send_notification() {
  curl -H "YOUR_HEADER" -H "Priority: $2" -H "Tags: $3" -d "$4" https://your-notification-service.com/backup-docker # Replace with the actual URL
}

# Check if "correct_location.md" file is present
if [ ! -f "$backupDirectory/correct_location.md" ]; then
  echo "Error: 'correct_location.md' file not found. Backup process aborted."

  # Log the error to the log file
  log_to_file "Backup failed: 'correct_location.md' file not found."

  # Send notification about backup failure
  date=$(date +'%Y-%m-%d')
  time=$(date +'%H:%M:%S')
  send_notification "Title: ❌📦 Backup $container Failed" "high" "error,$date" "Backup for $container on $backupDate failed. 'correct_location.md' file not found. 
  Date: $date 
  Time: $time"

  exit 1
fi

# Notify that the backup is starting
startDate=$(date +'%Y-%m-%d')
send_notification "Title: 📦 Backup $container Started" "low" "info,$startDate" ""

# Stop the container
echo "Stopping the Docker container: $container"
docker stop $container

# Loop through volumes and create backups
for volume in $(docker inspect --format '{{ range .Mounts }}{{ if eq .Type "volume" }}{{ .Name }} {{ end }}{{ end }}' $container); do
  echo "Creating backup for volume: $volume"
  cd $backupDirectory

  # Use tar to create the archive and send errors to a log file only if they occur
  if tar -cf - -C /var/lib/docker/volumes/$volume . | pv -s $(du -sb /var/lib/docker/volumes/$volume | awk '{print $1}') | nice -n 19 pigz -p2 > $container-$volume-$backupDate.tar.gz 2> backup_error.log; then
    echo "Backup for volume $volume successful."
  else
    echo "Backup for volume $volume failed. Check the error log for details: backup_error.log"
    # Log the failure to the log file
    log_to_file "Backup for volume $volume failed. Check the error log for details."
  fi
done

# Get end time
endTime=$(date +%s)

# Calculate the time spent in seconds
duration=$((endTime - startTime))

# Format the duration into HH:MM:SS
formattedDuration=$(date -u -d @$duration +'%H:%M:%S')

# Reassign date and time after successful backup
date=$(date +'%Y-%m-%d')
time=$(date +'%H:%M:%S')

# Check the number of backups and remove the oldest if more than the limit
for volume in $(docker inspect --format '{{ range .Mounts }}{{ if eq .Type "volume" }}{{ .Name }} {{ end }}{{ end }}' $container); do
  backupCount=$(ls -1 $backupDirectory/$container-$volume-*.tar.gz 2>/dev/null | wc -l)
  echo "Number of existing backups for volume $volume: $backupCount"

  if [ "$backupCount" -gt "$maxBackups" ]; then
    # Sort backups by modification time and remove the oldest ones
    echo "Removing oldest backup(s) for volume $volume to maintain a maximum of $maxBackups backups"
    ls -t $backupDirectory/$container-$volume-*.tar.gz | tail -n +$(($maxBackups + 1)) | xargs rm --
  fi
done

# Start the container again
echo "Starting the Docker container: $container"
docker start $container

# Include datetime and time spent in the notification message on new lines
endDatetime=$(date +'%Y-%m-%d %H:%M:%S')
successMessage="Backup for $container on $backupDate successful. 
Date: $date 
Time: $time 
Time Spent: $formattedDuration"
echo -e "Backup and cleanup process completed at:\n$endDatetime.\nTime spent: $formattedDuration\n$successMessage"

# Send notification about successful backup with green checkmark
send_notification "Title: ✅📦 Backup $container Completed" "low" "success,$date" "$successMessage"

# Log the completion of the process to the log file
log_to_file "Backup and cleanup process for $container completed."

echo "Backup and cleanup process for $container completed."
