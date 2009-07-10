#!/bin/bash

# Verify we are root
if [ "$USER" != "root" ]; then
  echo "You must run this script as root"
  exit 1
fi

# Verify that it is installed
if [ ! -d /var/lib/tomcat6 ]; then
  echo "You must first install tomcat from the apt repository"
  exit 1
fi

# Verify that it is installed
if [ -d /var/lib/tomcat6/instances ]; then
  echo "Multiple instances already setup on this box for Tomcat6.0"
  exit 1
fi

# Shutdown any running instace
if ! /etc/init.d/tomcat6 stop; then
  echo "Unable to stop the running tomcat instance. Please stop it before running this script."
  exit 1
fi

# Remove everything from the lib dir (this removes symlinks and files first then recursively everything else)
rm /var/lib/tomcat6/* > /dev/null 2>&1
rm -rf /var/lib/tomcat6 > /dev/null 2>&1

# Remove all the symlinks from the share dir and fix the perms
rm /usr/share/tomcat6/* > /dev/null 2>&1
chown -R tomcat6:nogroup /usr/share/tomcat6
chmod -R o-rwx /usr/share/tomcat6

# Clean up defaults for the template script
mv /etc/default/tomcat6 /etc/default/tomcat6-not-used

# Make the instances layout  
mkdir /var/lib/tomcat6/instances
chown -R tomcat6:nogroup /var/lib/tomcat6/instances
chmod -R o-rwx /var/lib/tomcat6/instances

# Clean up the logs
mkdir /var/log/tomcat6/old
mv /var/log/tomcat6/* /var/log/tomcat6/old > /dev/null 2>&1
mkdir /var/log/tomcat6/instances
chown -R tomcat6:nogroup /var/log/tomcat6/*
chmod -R o-rwx /var/log/tomcat6/*

# Backup the original init.d script just in case
if [ -f /etc/init.d/tomcat6 ]; then
	mv /etc/init.d/tomcat6 /etc/tomcat6/original-init-script
fi

# Remove the old init script and turn off all script links for the run levels
update-rc.d -f tomcat6 remove

echo "Successfully setup the machine for multiple tomcat instances and cleaned up the single instance layout"

