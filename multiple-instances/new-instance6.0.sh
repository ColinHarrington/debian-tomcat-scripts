#!/bin/bash

if [ "$USER" != "root" ]; then
  echo "You must run this script as root"
  exit 1
fi

if [ $# != 3 ]; then
  echo "Usage: new-instance.sh <domain-name> <port> <jk-port>"
  exit 1
fi

# Get the working dir
script_dir=$(dirname $0)
cd ${script_dir}
script_dir=$PWD
cd -

# Setup the variables
host_name=$1
port=$2
jk_port=$3
host_name_underscores=${host_name//\./_}
instance_dir=/var/lib/tomcat6/instances/${host_name}
log_dir=/var/log/tomcat6/instances/${host_name}

# Setup the instance directory
if [ -d ${instance_dir} ]; then
  echo "Instance ${host_name} already created."
  exit 1
fi
mkdir -p ${instance_dir}

# Copy the files and token replace
mkdir ${instance_dir}/conf ${instance_dir}/webapps ${instance_dir}/bin ${instance_dir}/temp ${instance_dir}/work
if ! cp /etc/tomcat6/web.xml ${instance_dir}/conf; then
  echo "Unable to create new instance ${host_name} because /etc/tomcat6/web.xml doesn't appear to exist"
  exit 1
fi

if ! sed "s/@HOST_NAME@/${host_name}/g" ${script_dir}/tomcat6/server.xml | sed "s/@HOST_NAME_UNDERSCORES@/${host_name_underscores}/g" | sed "s/@PORT@/${port}/g" | sed "s/@JK_PORT@/${jk_port}/g" > ${instance_dir}/conf/server.xml; then
  echo "Unable to create new instance ${host_name} because ${script_dir}/tomcat6/server.xml doesn't appear to exist"
  exit 1
fi

if ! sed "s/@HOST_NAME@/${host_name}/g" ${script_dir}/init.d/tomcat6 > ${instance_dir}/bin/tomcat6-init-script; then
  echo "Unable to find the custom ${script_dir}/init.d/tomcat6 file. This file must exist."
  exit 1
fi

# Add the Mod_JK worker defition
if ! sed "s/@HOST_NAME@/${host_name}/g" ${script_dir}/apache2/workers.properties | sed "s/@JK_PORT@/${jk_port}/g" >> /etc/libapache2-mod-jk/workers.properties; then
  echo "Unable to create new instance ${host_name} because the /etc/libapache2-mod-jk/workers.properties file couldn't be updated. Assuming machine doesn't use MOD JK."
else
  if ! sed "s/\(worker\.list.*\)/\1,${host_name}/g" /etc/libapache2-mod-jk/workers.properties > /tmp/workers.properties; then
    echo "Unable to create new instance ${host_name} because the worker.list property in the /etc/libapache2-mod-jk/workers.properties file couldn't be updated."
    exit 1
  fi

  if ! mv /tmp/workers.properties /etc/libapache2-mod-jk/workers.properties; then
    echo "Unable to move the modified workers.properties to /etc/libapache2-mod-jk."
    exit 1
  fi

  # Setup apache configuration
  if ! sed "s/@HOST_NAME@/${host_name}/g" ${script_dir}/apache2/site > /etc/apache2/sites-available/${host_name}; then
    echo "Unable to setup Apache2 configuration for the new Tomcat instance"
    exit 1
  fi

  if ! a2ensite ${host_name}; then
    echo "Unable to enable Apache2 site configuration"
    exit 1
  fi

  if [ ! -f /etc/apache2/conf.d/mod_jk ]; then
    if ! cp ${script_dir}/apache2/mod_jk /etc/apache2/conf.d; then
      echo "Unable to copy mod_jk configuration to /etc/apache/conf.d. You will have to do this manually."
    fi
  fi
fi

# Set the permissions to protect the instance
chown -R tomcat6:nogroup ${instance_dir}
chmod -R o-rwx ${instance_dir}
chmod ug+rx ${instance_dir}/bin/tomcat6-init-script

# Setup the logs
mkdir ${log_dir}
chown -R tomcat6:nogroup ${log_dir}
chmod -R o-rwx ${log_dir}
ln -s ${log_dir} ${instance_dir}/logs

# Create catalina.policy (for the security manager)
echo "// This file is an example of a policy file. You can edit this file for the specific instance" > ${instance_dir}/conf/catalina.policy.example
echo ""  >> ${instance_dir}/conf/catalina.policy.example
cat /etc/tomcat6/policy.d/*.policy >> ${instance_dir}/conf/catalina.policy.example
chown tomcat6:nogroup ${instance_dir}/conf/catalina.policy.example
chmod o-rwx ${instance_dir}/conf/catalina.policy.example

# Setup auto start
cp ${instance_dir}/bin/tomcat6-init-script /etc/init.d/tomcat6_${host_name}
update-rc.d tomcat6_${host_name} defaults 90

# Create the web directory
mkdir -p /var/tomcat6/${host_name}/website
chown -R tomcat6:nogroup /var/tomcat6
