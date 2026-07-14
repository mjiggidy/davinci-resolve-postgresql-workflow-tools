#!/bin/bash

# prompt user for the name of the database
read -p "What is the name of the database for which you'd like to stop automatically backing up and optimizing? " dbname

# confirm that the name of the database is correct
echo "You entered: $dbname"
read -p "Is that correct? Enter y or no: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Create a sanitized version of the database name for use in related filenames
pathname=$(printf %s "$dbname" | tr -Cs "[:alnum:]" "_")

# stop backup systemd timer
systemctl stop backup-${pathname}.timer

# stop backup systemd service
systemctl stop backup-${pathname}.service

# stop optimize systemd timer
systemctl stop optimize-${pathname}.timer

# stop optimize systemd service
systemctl stop optimize-${pathname}.service

# disable backup systemd timer
systemctl disable backup-${pathname}.timer

# disable backup systemd service
systemctl disable backup-${pathname}.service

# disable optimize systemd timer
systemctl disable optimize-${pathname}.timer

# disable optimize systemd service
systemctl disable optimize-${pathname}.service

# remove backup systemd timer file
rm /etc/systemd/system/backup-${pathname}.timer

# remove backup systemd service file
rm /etc/systemd/system/backup-${pathname}.service

# remove optimize systemd timer file
rm /etc/systemd/system/optimize-${pathname}.timer

# remove optimize systemd service file
rm /etc/systemd/system/optimize-${pathname}.service

# remove backup shell script
rm /usr/local/DaVinci-Resolve-PostgreSQL-Workflow-Tools/backup/backup-${pathname}.sh

# remove optimize shell script
rm /usr/local/DaVinci-Resolve-PostgreSQL-Workflow-Tools/optimize/optimize-${pathname}.sh

# log to monthly log file that $dbname has been uninstalled. $dbname will no longer be backed up or optimized
echo "Backup and optimize tools for $dbname were uninstalled at $(date "+%Y_%m_%d_%H_%M"). $dbname will no longer be backed up or optimized." >> /usr/local/DaVinci-Resolve-PostgreSQL-Workflow-Tools/logs/logs-$(date "+%Y_%m").log

# send message to user in command-line program to inform them of the same
echo "Backup and optimize tools for ${dbname} were uninstalled. Have a great day!"
