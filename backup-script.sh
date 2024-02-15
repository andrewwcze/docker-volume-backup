# Author: andrewwcze
#Description: Docker volume backup script
# This script creates a tar archive of a Docker volume and sends a notification(ntfy) about the backup process.
# It also removes the oldest backup if the number of backups exceeds a specified limit.
# The script uses the "pv" command to show the progress of the backup process.
# The script also uses the "curl" command to send notifications to a web service.
# The script assumes that the Docker container is running and that the "pv" and "curl" commands are installed.
# The script also assumes that the "correct_location.md" file is present in the backup directory.
# The script should be modified to include the correct backup directory, container name, and notification URL.
# The script should be run as a (sudo) cron job at regular intervals to create backups.
# The script should be run with the "bash" shell to use the "date" command with the correct format.
# The script should be run with the "sh" shell to use the "date" command with the correct format.

#=================================================================================================================

#!/bin/bash

# Set up variables
container=<container_name>
backupDirectory="/path/to/docker-backups"
logFile="$backupDirectory/backup.log"
backupDate=$(date +'%Y-%m-%d_%H-%M')
startTime=$(date +%s)

# Function to log datetime and status to the log file
log_to_file() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$logFile"
}

# Function to send notifications
send_notification() {
  curl -H "$1" -H "Priority: $2" -H "Tags: $3" -d "$4" https://your-notification-url/backup-docker
}

# Check if "correct_location.md" file is present
if [ ! -f "$backupDirectory/correct_location.md" ]; then
  echo "Error: 'correct_location.md' file not found. Backup process aborted."

  # Log the error to the log file
  log_to_file "Backup failed: 'correct_location.md' file not found."

  # Send notification about backup failure
  date=$(date +'%Y-%m-%d')
  time=$(date +'%H:%M:%S')
  send_notification "Title: ❌📦 Backup $container Failed" "high" "error,$date" "Backup for $container on $backupDate failed. 'correct_location.md' file not found. Date: $date Time: $time"

  exit 1
fi

# Notify that the backup is starting
startDate=$(date +'%Y-%m-%d')
send_notification "Title: 📦 Backup $container Started" "low" "info,$startDate" ""

# Stop the container
echo "Stopping the Docker container: $container"
docker stop $container

# Create a tar archive of the docker parent folder
echo "Creating backup: $backupDirectory/$container-$backupDate.tar.gz"
cd $backupDirectory

# Use tar to create the archive and send errors to a log file only if they occur
if tar -cf - -C /var/lib/docker/volumes/$container . | pv -s $(du -sb /var/lib/docker/volumes/$container | awk '{print $1}') | gzip > $container-$backupDate.tar.gz 2> backup_error.log; then
  echo "Backup successful."

  # Get end time
  endTime=$(date +%s)

  # Calculate the time spent in seconds
  duration=$((endTime - startTime))

  # Format the duration into HH:MM:SS
  formattedDuration=$(date -u -d @$duration +'%H:%M:%S')

  # Check the number of backups and remove the oldest if more than the limit
  backupCount=$(ls -1 $backupDirectory/$container-*.tar.gz 2>/dev/null | wc -l)
  echo "Number of existing backups: $backupCount"

  if [ "$backupCount" -gt 2 ]; then
    # Sort backups by modification time and remove the oldest one
    echo "Removing oldest backup(s) to maintain a maximum of 2 backups"
    ls -t $backupDirectory/$container-*.tar.gz | tail -n +3 | xargs rm --
  fi

  # Start the container again
  echo "Starting the Docker container: $container"
  docker start $container

  # Include datetime and time spent in the notification message on new lines
  endDatetime=$(date +'%Y-%m-%d %H:%M:%S')
  successMessage="Backup for $container on $backupDate successful. Date: $date Time: $time Time Spent: $formattedDuration"
  echo -e "Backup and cleanup process completed at:\n$endDatetime.\nTime spent: $formattedDuration\n$successMessage"

  # Send notification about successful backup with green checkmark
  send_notification "Title: ✅📦 Backup $container Completed" "low" "success,$date" "$successMessage"
else
  echo "Backup failed. Check the error log for details: backup_error.log"

  # Log the failure to the log file
  log_to_file "Backup failed. Check the error log for details."

  # Include datetime in the notification message on a new line
  endDatetime=$(date +'%Y-%m-%d %H:%M:%S')

  # Send notification about backup failure and include the error log
  errorMessage="Backup for $container on $backupDate failed. Check the error log for details. Date&time:\n$endDatetime."
  send_notification "Title: ❌📦 Backup $container Failed" "high" "error,$date" "$errorMessage" -F "files[]=@backup_error.log"
fi

# Log the completion of the process to the log file
log_to_file "Backup and cleanup process completed."

echo "Backup and cleanup process completed."
