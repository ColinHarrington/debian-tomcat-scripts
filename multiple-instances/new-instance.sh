#!/bin/bash

if [ "$USER" != "root" ]; then
  echo "You must run this script as root"
  exit 1
fi

if [ $# != 2 ]; then
  echo "Usage: new-instance.sh <instance-name> <domain-name>"
  exit 1
fi

# Get the working dir
script_dir=$(dirname $0)
cd $script_dir
script_dir=$PWD
cd -

# Setup the variables
instance_name=$1
host_name=$2
domain_name=$($script_dir/domain-name.rb $host_name)
instance_dir=/var/lib/tomcat5.5/instances/$1
log_dir=/var/log/tomcat5.5/instances/$1

# Setup the instance directory
cd /var/lib/tomcat5.5/instances
if [ -d $instance_name ]; then
  echo "Instance $instance_name already created."
  exit 1
fi
mkdir $instance_name

# Copy the files and token replace
mkdir $instance_dir/conf $instance_dir/webapps $instance_dir/bin $instance_dir/temp $instance_dir/work
if ! cp $script_dir/web.xml $instance_dir/conf; then
  echo "Unable to create new instance $1 because $script_dir/web.xml doesn't appear to exist"
  exit 1
fi

if ! sed "s/@HOST_NAME@/$host_name/g" $script_dir/server.xml > $instance_dir/conf/server.xml; then
  echo "Unable to create new instance $1 because $script_dir/server.xml doesn't appear to exist"
  exit 1
fi

if ! sed "s/@INSTANCE_NAME@/$instance_name/g" $script_dir/tomcat.sh > $instance_dir/bin/tomcat.sh; then
  echo "Unable to find the custom tomcat.sh file in $script_dir. This file must exist."
  exit 1
fi

# Setup apache configuration
if ! sed "s/@HOST_NAME@/$host_name/g" $script_dir/apache2-conf | sed "s/@DOMAIN_NAME@/$domain_name/g" > /etc/apache2/sites-available/$host_name; then
  echo "Unable to setup Apache2 configuration for the new Tomcat instance"
  exit 1
fi

if ! a2ensite $host_name; then
  echo "Unable to enable Apache2 site configuration"
  exit 1
fi

# Set the permissions to protect the instance
chown -R tomcat55:nogroup $instance_dir
chmod -R o-rwx $instance_dir
chmod -R g+w $instance_dir
chmod ug+rx $instance_dir/bin/tomcat.sh

# Setup the logs
mkdir $log_dir
chown -R tomcat55:nogroup $log_dir
chmod -R o-rwx $log_dir
chmod -R g+w $log_dir
ln -s $log_dir $instance_dir/logs

# Create catalina.policy (for the security manager)
echo "// This file is an example of a policy file. You can edit this file for the specific instance" > conf/catalina.policy.example
echo ""  >> conf/catalina.policy.example
cat /etc/tomcat5.5/policy.d/*.policy >> conf/catalina.policy.example
chown tomcat55:nogroup conf/catalina.policy.example
chmod o-rwx conf/catalina.policy.example
chmod g+w conf/catalina.policy.example

# Setup auto start
ln -s $instance_dir/bin/tomcat.sh /etc/init.d/tomcat5.5_$instance_name
update-rc.d tomcat5.5_$instance_name defaults 90
