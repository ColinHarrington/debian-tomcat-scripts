#!/bin/bash

if [ "$USER" != "root" ]; then
  echo "You must run this script as root"
  exit 1
fi

if [ $# != 1 ]; then
  echo "Usage: rm-instance.sh <host-name>"
  exit 1
fi

# Get the working dir
script_dir=$(dirname $0)
cd $script_dir
script_dir=$PWD
cd - > /dev/null

# Setup the variables
host_name=$1
port=$2
jk_port=$3
instance_name=${host_name//\./_}
domain_name=$($script_dir/domain-name.rb $host_name)
instance_dir=/var/lib/tomcat5.5/instances/$instance_name
log_dir=/var/log/tomcat5.5/instances/$instance_name

if [ ! -d $instance_dir ]; then
  echo "Invalid instance $host_name ($instance_dir is missing)"
  exit 1
fi

# Remove the instance directory
rm -r $instance_dir

# Remove the apache configuration

if ! a2dissite $host_name; then
  echo "Unable to disable Apache2 site configuration"
fi

if ! rm /etc/apache2/sites-available/$host_name; then 
  echo "Unable to remove apache site configuration"
fi 

# Remove the logs
rm -r $log_dir

# Setup auto start
rm /etc/init.d/tomcat5.5_$instance_name
update-rc.d tomcat5.5_$instance_name remove
