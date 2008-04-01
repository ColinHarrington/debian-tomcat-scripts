#!/bin/bash

if [ "$USER" != "root" ]; then
  echo "You must run this script as root"
  exit 1
fi

if [ $# != 2 ]; then
  echo "Usage: rm-instance.sh <instance-name> <host-name>"
  exit 1
fi

# Get the working dir
script_dir=$(dirname $0)
cd $script_dir
script_dir=$PWD
cd - > /dev/null

# Setup the variables
instance_name=$1
host_name=$2
instance_dir=/var/lib/tomcat5.5/instances/$1
log_dir=/var/log/tomcat5.5/instances/$1

if [ ! -d $instance_dir ]; then
  echo "Invalid instance $1"
  exit 1
fi

# Remove the instance directory
rm -rf $instance_dir

if ! a2dissite $host_name; then
  echo "Unable to disable Apache2 site configuration"
fi

# Remove the logs
rm -rf $log_dir

# Setup auto start
rm /etc/init.d/tomcat5.5_$instance_name
update-rc.d tomcat5.5_$instance_name remove
