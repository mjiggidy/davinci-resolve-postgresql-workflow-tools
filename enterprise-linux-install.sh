#!/bin/bash

PATH_TOOLS="/usr/local/DaVinci-Resolve-PostgreSQL-Workflow-Tools"

# Here's where the user is going to enter the Resolve database name, as it appears in the GUI:
read -p "Enter the name of your DaVinci Resolve PostgreSQL database: " dbname

# Let's allow the user to confirm that what they've typed in is correct:
echo "You entered: $dbname"
read -p "Is that correct? Enter y or n: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Create a sanitized version of the database name for use in related filenames
pathname=$(printf %s "$dbname" | tr -Cs "[:alnum:]" "_")

# Now "$dbname" will work as a variable in subsequent paths.

# Let's prompt the user for the "backup directory," which is where the backups from pg_dump will go:
read -e -p "Into which directory should the database backups go? Use absolute paths! " backupDirectory

# Let's also allow the user to confirm that what they've typed in for the backup directory is correct:
echo "You entered: $backupDirectory"
read -p "Is that correct? Enter y or n: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Now $backupDirectory will be the folder loaded into the shell script where the backups are going to go.

# Let's allow the user to specify how often to backup the database.
# Let's also provide a link for more information on systemd time syntax.
echo "See https://www.freedesktop.org/software/systemd/man/systemd.time.html for time syntax."
echo "Suggestion: 1h"
read -p "How often would you like to backup the database? " backupFrequency

# Let's have the user confirm that they entered the right backup frequency:
read -p "You entered that you want to backup your database every "$backupFrequency". Is that correct? Enter y or n: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Let's allow the user to specify how often to optimize the database.
# Let's also provide another link to more information on systemd time syntax.
echo "See https://www.freedesktop.org/software/systemd/man/systemd.time.html for time syntax."
echo "Suggestion: 1d"
read -p "How often would you like to optimize the database? " optimizeFrequency

# Let's have the user confirm that they entered the correct optimizing frequency:
read -p "You entered that you want to optimize your database every "$optimizeFrequency". Is that correct? Enter y or n: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Let's check if a /usr/local/DaVinci-Resolve-PostgreSQL-Workflow-Tools folder exists, and if it doesn't, let's create one:
mkdir -p "${PATH_TOOLS}"

# Let's also check to see if there are separate directories for "backup" and "optimize" scripts, and if they don't exist, let's create them.
# We're making separate directories for the different kinds of scripts just to keep everything clean and organized.

mkdir -p "${PATH_TOOLS}/backup"
mkdir -p "${PATH_TOOLS}/optimize"

# Let's also make a folder for log files
mkdir -p "${PATH_TOOLS}/logs"


# We also need to make sure that these folders in which the scripts are living have the proper permissions to execute:
chmod -R 755 "${PATH_TOOLS}/backup"
chmod -R 755 "${PATH_TOOLS}/optimize"
chmod -R 777 "${PATH_TOOLS}/logs"

# Let's make sure a log file exists if it doesn't already
touch "${PATH_TOOLS}/logs/logs-$(date +%Y_%m).log"

# Let's make sure that that log file can be read from and written to
chmod 777 "${PATH_TOOLS}/logs/logs-$(date +%Y_%m).log"

# Let's go ahead and create the two different shell scripts that will be executed by the systemd files.

# First, let's create the "backup" shell script:
touch "${PATH_TOOLS}/backup/backup-${pathname}.sh"

# Now, let's fill it in:
cat << EOF > "${PATH_TOOLS}/backup/backup-${pathname}.sh"
#!/bin/bash
# Let's perform the backup and log to the monthly log file if the backup is successful.
/usr/pgsql-13/bin/pg_dump --host localhost --username postgres "$dbname" --blobs --file "${backupDirectory}/${pathname}_\$(date "+%Y_%m_%d_%H_%M").backup" --format=custom --verbose --no-password && \\
echo "${dbname} was backed up at \$(date "+%Y_%m_%d_%H_%M") into "${backupDirectory}"." >> "${PATH_TOOLS}/logs/logs-\$(date "+%Y_%m").log"
EOF

# To make sure that this backup script will run without a password, we need to add a .pgpass file to ~ if it doesn't already exist:
if [ ! -f /root/.pgpass ]; then
	touch /root/.pgpass
	echo "localhost:5432:*:postgres:DaVinci" > /root/.pgpass
# 	We also need to make sure that that .pgpass file has the correct permissions of 0600:
	chmod 0600 /root/.pgpass
fi

# Let's move onto the "optimize" script:
touch "${PATH_TOOLS}/optimize/optimize-${pathname}.sh"
cat << EOF > "${PATH_TOOLS}/optimize/optimize-${pathname}.sh"
#!/bin/bash
# Let's optimize the database and log to the monthly log file if the optimization is successful.
/usr/pgsql-13/bin/reindexdb --host localhost --username postgres $dbname --no-password --echo && \\
/usr/pgsql-13/bin/vacuumdb --analyze --host localhost --username postgres $dbname --verbose --no-password && \\
echo "${dbname} was optimized at \$(date "+%Y_%m_%d_%H_%M")." >> "${PATH_TOOLS}/logs/logs-\$(date "+%Y_%m").log"
EOF

# Now each individual shell script needs to have their permissions set properly for systemd to read and execute the scripts, so let's use 755:
chmod 755 "${PATH_TOOLS}/backup/backup-${pathname}.sh"
chmod 755 "${PATH_TOOLS}/optimize/optimize-${pathname}.sh"

# With both shell scripts created with the proper permissions, we can create, load, and start the systemd services and timers.

# Let's create the "backup" service and timer first.
touch /etc/systemd/system/backup-${pathname}.service
cat << EOF > /etc/systemd/system/backup-${pathname}.service
[Unit]
Description=Backup of $dbname DaVinci Resolve PostgreSQL database

[Service]
Type=oneshot
ExecStart=${PATH_TOOLS}/backup/backup-${pathname}.sh
EOF

touch /etc/systemd/system/backup-${pathname}.timer
cat << EOF > /etc/systemd/system/backup-${pathname}.timer
[Unit]
Description=Backup of $dbname DaVinci Resolve PostgreSQL database

[Timer]
OnUnitActiveSec=$backupFrequency
OnBootSec=60s
AccuracySec=1s
RandomizedDelaySec=180s

[Install]
WantedBy=timers.target
EOF

# Now let's create the "optimize" service and timer.
touch /etc/systemd/system/optimize-${pathname}.service
cat << EOF > /etc/systemd/system/optimize-${pathname}.service
[Unit]
Description=Optimize $dbname DaVinci Resolve PostgreSQL database

[Service]
Type=oneshot
ExecStart=${PATH_TOOLS}/optimize/optimize-${pathname}.sh
EOF

touch /etc/systemd/system/optimize-${pathname}.timer
cat << EOF > /etc/systemd/system/optimize-${pathname}.timer
[Unit]
Description=Optimize $dbname DaVinci Resolve PostgreSQL database

[Timer]
OnUnitActiveSec=$optimizeFrequency
OnBootSec=60s
AccuracySec=1s
RandomizedDelaySec=180s

[Install]
WantedBy=timers.target
EOF

# These systemd files each need permissions of 755.
chmod 755 /etc/systemd/system/backup-${pathname}.service
chmod 755 /etc/systemd/system/backup-${pathname}.timer
chmod 755 /etc/systemd/system/optimize-${pathname}.service
chmod 755 /etc/systemd/system/optimize-${pathname}.timer

# Now, the "backup" and "optimize" scripts and systemd files are in place.
# All we need to do is enable and start the timers.

systemctl daemon-reload
systemctl enable --now backup-${pathname}.timer
systemctl enable --now optimize-${pathname}.timer

echo "Congratulations, $dbname will be backed up every "$backupFrequency" and optimized every "$optimizeFrequency"."
echo "You can check to make sure that everything is being backed up and optimized properly by periodically looking at the log files in: ${PATH_TOOLS}/logs"
echo "Have a great day!"
