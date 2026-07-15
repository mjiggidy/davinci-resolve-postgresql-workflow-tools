#!/bin/bash

# prompt user for the name of the database
read -p "What is the name of the database for which you'd like to stop automatically backing up and optimizing? " dbname

# confirm that the name of the database is correct
echo "You entered: $dbname"
read -p "Is that correct? Enter y or no: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Create a sanitized version of the database name for use in related filenames
pathname=$(printf %s "$dbname" | tr -Cs "[:alnum:]" "_")

# stop backup launchd job
launchctl stop com.resolve.backup.$pathname

# unload backup plist file
launchctl unload /Library/LaunchDaemons/backup-$pathname.plist

# stop optimize launchd job
launchctl stop com.resolve.optimize.$pathname

# unload optimize plist file
launchctl unload /Library/LaunchDaemons/optimize-$pathname.plist

# remove backup launchd plist file
rm /Library/LaunchDaemons/backup-$pathname.plist

# remove optimize launchd plist file
rm /Library/LaunchDaemons/optimize-$pathname.plist

# remove backup shell script
rm /Users/Shared/DaVinci-Resolve-PostgreSQL-Workflow-Tools/backup/backup-$pathname.sh

# remove optimize shell script
rm /Users/Shared/DaVinci-Resolve-PostgreSQL-Workflow-Tools/optimize/optimize-$pathname.sh

# log to monthly log file that $dbname has been uninstalled. $dbname will no longer be backed up or optimized
echo "Backup and optimize tools for $dbname were uninstalled at $(date "+%Y_%m_%d_%H_%M"). $dbname will no longer be backed up or optimized." >> /Users/Shared/DaVinci-Resolve-PostgreSQL-Workflow-Tools/logs/logs-$(date "+%Y_%m").log

# send message to user in command-line program to inform them of the same
echo "Backup and optimize tools for ${dbname} were uninstalled. Have a great day!"
