# Docker Volume Backup Script
**Author:** andrewwcze
**Version:** 2024.03.21

Tested on: Raspberry Pi 4 Model B Rev 1.2
OS: Debian GNU/Linux 11 (bullseye) 
Kernel: Linux 6.1.21-v8+
Arch.: arm64

**Description:**
This script automates the backup process for a Docker volume, providing notifications via ntfy (notification service). The script also manages backup retention by removing the oldest backup when the specified limit is exceeded. Key components include the "pv" command to display backup progress and the "curl" command to send notifications to an external service. Prerequisites include a running Docker container, the installation of "pv" and "curl" commands, and the presence of the "correct_location.md" file in the backup directory.

**Usage Instructions:**
1. Modify the script with the correct values for `container`, `backupDirectory`, and the `notification URL`.
2. Run the script as a (sudo) cron job at regular intervals for automated backups.
3. Ensure the script is executed with the "bash" shell to utilize the "date" command with the correct format.
4. Alternatively, execute the script with the "sh" shell for proper "date" command usage.
5. **The script assumes that the `container name` and `volume name` are identical. Ensure they match in your setup.**

**Script Flow:**
1. Checks for the existence of "correct_location.md" file; aborts if not found, logging the error and sending a high-priority notification.
2. Sends a low-priority notification indicating the start of the backup process.
3. Stops the Docker container specified by `container`.
4. Creates a folder with the name of the `container` if it doesn't exist in the `backupDirectory`.
5. Creates a tar archive of the Docker volume inside the folder, displaying progress with "pv," and captures errors in the "backup_error.log" file.
6. If successful, logs the completion, restarts the Docker container, and sends a low-priority notification with details.
7. If unsuccessful, logs the failure, sends a high-priority notification with details, and includes the error log in the notification.
8. Removes the oldest backup files if the number of backups exceeds the specified limit.
9. Restarts the Docker container.

**Note:** 
- Adjust the script to your specific needs and environment.
- Ensure the "correct_location.md" file is present and the specified paths are accurate.
- Make sure to install the required dependencies (e.g., "pv" and "curl").
- Enjoy! 😊
