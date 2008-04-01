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

# Copy over the tomcat.sh file before we change directories
if [ ! -f tomcat.sh ]; then
  echo "The tomcat.sh file is missing. It must be in the current directory so it can be placed"
  echo "into the new layout"
  exit 1
fi
cp tomcat.sh /etc/tomcat5.5
chmod go-wx /etc/tomcat5.5/tomcat.sh

# Now, head out and clean up
if ! cd /var/lib/tomcat5.5; then
  echo "You must first install tomcat from the apt repository"
  exit 1
fi

# Make the instances layout  
mkdir instances
chown -R tomcat55:nogroup instances
chmod -R o-rwx instances
chmod -R g+w instances

# Clean up old layout
rm work
rm -rf webapps
rmdir temp
rmdir shared/classes
rmdir shared/lib
rmdir shared
rm logs
rm -rf conf

cd /usr/share/tomcat5.5
rm conf
rm logs
rm shared
rm temp
rm work

# Clean up defaults for the template script
cd /etc/default/
mv tomcat5.5 tomcat-bak
mkdir -p tomcat5.5/instances tomcat5.5/template
mv tomcat-bak tomcat5.5/template/tomcat5.5
chown -R root:root tomcat5.5
chmod -R go-w tomcat5.5
chmod -R g+r tomcat5.5

# Clean up the logs
cd /var/log/tomcat5.5
mkdir old
mv * old
mkdir instances
chown -R tomcat55:nogroup *
chmod -R o-rwx old instances
chmod -R g+w old instances

# Remove the old init script and turn off all script links for the run levels
rm /etc/init.d/tomcat5.5
update-rc.d -f tomcat5.5 remove

echo "Successfully setup the machine for multiple tomcat instances and cleaned up the single instance layout"

