#!/bin/bash

if [ "$USER" != "root" ]; then
  echo "You must run this script as root"
  exit 1
fi

if ! ruby --version > /dev/null; then
  echo "You must have ruby installed on the system to use this script"
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
domain_name=$(${script_dir}/domain-name.rb ${host_name})
instance_dir=/var/lib/tomcat5.5/instances/${host_name}
log_dir=/var/log/tomcat5.5/instances/${host_name}

# Setup the instance directory
if [ -d ${instance_dir} ]; then
  echo "Instance $hose_name already created."
  exit 1
fi
mkdir -p ${instance_dir}

# Copy the files and token replace
mkdir ${instance_dir}/conf ${instance_dir}/webapps ${instance_dir}/bin ${instance_dir}/temp ${instance_dir}/work
if ! cp ${script_dir}/web.xml ${instance_dir}/conf; then
  echo "Unable to create new instance ${host_name} because ${script_dir}/web.xml doesn't appear to exist"
  exit 1
fi

if ! sed "s/@HOST_NAME@/${host_name}/g" ${script_dir}/server.xml | sed "s/@HOST_NAME_UNDERSCORES@/${host_name_underscores}/g" | sed "s/@PORT@/${port}/g" | sed "s/@JK_PORT@/${jk_port}/g" > ${instance_dir}/conf/server.xml; then
  echo "Unable to create new instance ${host_name} because ${script_dir}/server.xml doesn't appear to exist"
  exit 1
fi

if ! sed "s/@HOST_NAME_UNDERSCORES@/${host_name_underscores}/g" ${script_dir}/tomcat.sh > ${instance_dir}/bin/tomcat.sh; then
  echo "Unable to find the custom tomcat.sh file in ${script_dir}. This file must exist."
  exit 1
fi

# Add the Mod_JK worker defition
if ! sed "s/@HOST_NAME@/${host_name}/g" ${script_dir}/workers.properties | sed "s/@JK_PORT@/${jk_port}/g" >> /etc/libapache2-mod-jk/workers.properties; then
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
  if ! sed "s/@HOST_NAME@/${host_name}/g" ${script_dir}/apache2-conf | sed "s/@DOMAIN_NAME@/${domain_name}/g" | sed "s/@HOST_NAME_UNDERSCORES@/${host_name_underscores}/g" > /etc/apache2/sites-available/${host_name}; then
    echo "Unable to setup Apache2 configuration for the new Tomcat instance"
    exit 1
  fi

  if ! a2ensite ${host_name}; then
    echo "Unable to enable Apache2 site configuration"
    exit 1
  fi
fi

# Set the permissions to protect the instance
chown -R tomcat55:nogroup ${instance_dir}
chmod -R o-rwx ${instance_dir}
chmod -R g+w ${instance_dir}
chmod ug+rx ${instance_dir}/bin/tomcat.sh

# Setup the logs
mkdir ${log_dir}
chown -R tomcat55:nogroup ${log_dir}
chmod -R o-rwx ${log_dir}
chmod -R g+w ${log_dir}
ln -s ${log_dir} ${instance_dir}/logs

# Create catalina.policy (for the security manager)
echo "// This file is an example of a policy file. You can edit this file for the specific instance" > ${instance_dir}/conf/catalina.policy.example
echo ""  >> ${instance_dir}/conf/catalina.policy.example
cat ${script_dir}/policy.d/*.policy >> ${instance_dir}/conf/catalina.policy.example
chown tomcat55:nogroup ${instance_dir}/conf/catalina.policy.example
chmod o-rwx ${instance_dir}/conf/catalina.policy.example
chmod g+w ${instance_dir}/conf/catalina.policy.example

# Setup auto start
cp ${instance_dir}/bin/tomcat.sh /etc/init.d/tomcat5.5_${host_name}
update-rc.d tomcat5.5_${host_name} defaults 90

# Create the web directory
mkdir -p /opt/${host_name}/website
