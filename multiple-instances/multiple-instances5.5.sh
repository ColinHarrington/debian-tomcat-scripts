#!/bin/bash

# Verify we are root
if [ "$USER" != "root" ]; then
  echo "You must run this script as root"
  exit 1
fi

# Shutdown any running instace
if ! /etc/init.d/tomcat5.5 stop; then
  echo "Unable to stop the running tomcat instance. Please stop it before running this script."
  exit 1
fi

# Verify that it is installed
if [ ! -d /var/lib/tomcat5.5 ]; then
  echo "You must first install tomcat from the apt repository"
  exit 1
fi

# Remove everything from the lib dir (this removes symlinks and files first then recursively everything else)
rm /var/lib/tomcat5.5/* > /dev/null
rm -rf /var/lib/tomcat5.5/* > /dev/null

# Remove all the symlinks from the share dir
rm /usr/share/tomcat5.5/* > /dev/null

# Clean up defaults for the template script
cd /etc/default/
mv tomcat5.5 tomcat5.5-not-used

# Make the instances layout  
mkdir /var/lib/tomcat5.5/instances
chown -R tomcat55:nogroup /var/lib/tomcat5.5/instances
chmod -R o-rwx /var/lib/tomcat5.5/instances
chmod -R g+w /var/lib/tomcat5.5/instances

# Clean up the logs
mkdir /var/log/tomcat5.5/old
mv /var/log/tomcat5.5/* /var/log/tomcat5.5/old
mkdir /var/log/tomcat5.5/instances
chown -R tomcat55:nogroup /var/log/tomcat5.5/*
chmod -R o-rwx /var/log/tomcat5.5/*
chmod -R g+w /var/log/tomcat5.5/*

# Backup the original init.d script just in case
if [ -f /etc/init.d/tomcat5.5 ]; then
	mv /etc/init.d/tomcat5.5 /etc/tomcat5.5/original-init-script
fi

# Remove the old init script and turn off all script links for the run levels
update-rc.d -f tomcat5.5 remove

echo "Successfully setup the machine for multiple tomcat instances and cleaned up the single instance layout"

