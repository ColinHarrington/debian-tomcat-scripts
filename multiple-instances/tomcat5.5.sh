#!/bin/sh
#
# /etc/init.d/tomcat5.5 -- startup script for the Tomcat 5 servlet engine
#
# Written by Miquel van Smoorenburg <miquels@cistron.nl>.
# Modified for Debian GNU/Linux	by Ian Murdock <imurdock@gnu.ai.mit.edu>.
# Modified for Tomcat by Stefan Gybas <sgybas@debian.org>.
#
### BEGIN INIT INFO
# Provides:          tomcat
# Required-Start:    $local_fs $remote_fs $network
# Required-Stop:     $local_fs $remote_fs $network
# Should-Start:      $named
# Should-Stop:       $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start Tomcat.
# Description:       Start the Tomcat servlet engine.
### END INIT INFO

set -e

PATH=/bin:/usr/bin:/sbin:/usr/sbin
NAME=tomcat5.5
DESC="Tomcat servlet engine"
DAEMON=/usr/bin/jsvc
CATALINA_HOME=/usr/share/$NAME
HOST_NAME=@HOST_NAME@
DEFAULT=/etc/default/$NAME/instances/$HOST_NAME

. /lib/lsb/init-functions
. /etc/default/rcS

# The following variables can be overwritten in $DEFAULT

# Run Tomcat 5 as this user ID
TOMCAT5_USER=tomcat55

# The first existing directory is used for JAVA_HOME (if JAVA_HOME is not
# defined in $DEFAULT)
JDK_DIRS="/usr/lib/jvm/java-6-openjdk /usr/lib/jvm/java-6-sun /usr/lib/jvm/java-1.5.0-sun /usr/lib/j2sdk1.4-sun /usr/lib/j2sdk1.4-blackdown /usr/lib/j2se/1.4 /usr/lib/j2sdk1.5-sun /usr/lib/j2sdk1.3-sun /usr/lib/j2sdk1.3-blackdown /usr/lib/j2sdk1.5-ibm /usr/lib/j2sdk1.4-ibm /usr/lib/jvm/java-gcj /usr/lib/kaffe"

# Directory for per-instance configuration files and webapps
CATALINA_BASE=/var/lib/tomcat5.5/instances/$HOST_NAME

# Use the Java security manager? (yes/no)
TOMCAT5_SECURITY=no

# Timeout in seconds for the shutdown of all webapps
TOMCAT5_SHUTDOWN=30

# End of variables that can be overwritten in $DEFAULT

# overwrite settings from default file
if [ -f "$DEFAULT" ]; then
	. "$DEFAULT"
fi

test -f $DAEMON || exit 0

[ -z "$TOMCAT5_USER" ] && TOMCAT5_USER=tomcat55

# Look for the right JVM to use
for jdir in $JDK_DIRS; do
	if [ -r "$jdir/bin/java" -a -z "${JAVA_HOME}" ]; then
		JAVA_HOME_TMP="$jdir"
		# checks for a real JDK like environment, needed to check if 
		# really the java-gcj-compat-dev package is installed
		if [ -r "$jdir/bin/jdb" ]; then
			JAVA_HOME="$JAVA_HOME_TMP"
		fi
	fi
done
export JAVA_HOME

# Set java.awt.headless=true if JAVA_OPTS is not set so the
# Xalan XSL transformer can work without X11 display on JDK 1.4+
# It also looks like the default heap size of 64M is not enough for most cases
# se the maximum heap size is set to 128M
if [ -z "$JAVA_OPTS" ]; then
	JAVA_OPTS="-Djava.awt.headless=true -Xmx128M"
fi

JAVA_OPTS="$JAVA_OPTS -Djava.endorsed.dirs=$CATALINA_HOME/common/endorsed -Dcatalina.base=$CATALINA_BASE -Dcatalina.home=$CATALINA_HOME -Djava.io.tmpdir=$CATALINA_BASE/temp"

# Set the JSP compiler if set in the tomcat5.5.default file
if [ -n "$JSP_COMPILER" ]; then
	JAVA_OPTS="$JAVA_OPTS -Dbuild.compiler=$JSP_COMPILER"
fi

if [ "$TOMCAT5_SECURITY" = "yes" ]; then
	JAVA_OPTS="$JAVA_OPTS -Djava.security.manager -Djava.security.policy=$CATALINA_BASE/conf/catalina.policy"
fi

# juli LogManager disabled if running under libgcj (see bug #395167)
gcj=no
"$JAVA_HOME/bin/java" -version 2>&1 | grep -q "^gij (GNU libgcj)" && gcj=yes
if [ "$gcj" != "yes" ]; then
  JAVA_OPTS="$JAVA_OPTS -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager -Djava.util.logging.config.file=$CATALINA_BASE/conf/logging.properties"
fi

# Define other required variables
CATALINA_PID="/var/run/$NAME-$HOST_NAME.pid"
LOGFILE="$CATALINA_BASE/logs/catalina.out"
BOOTSTRAP_CLASS=org.apache.catalina.startup.Bootstrap
JSVC_CLASSPATH="/usr/share/java/commons-daemon.jar:$CATALINA_HOME/bin/bootstrap.jar"

# Look for Java Secure Sockets Extension (JSSE) JARs
if [ -z "${JSSE_HOME}" -a -r "${JAVA_HOME}/jre/lib/jsse.jar" ]; then
    JSSE_HOME="${JAVA_HOME}/jre/"
fi
export JSSE_HOME

case "$1" in
  start)
	if [ -z "$JAVA_HOME" ]; then
		log_failure_msg "no JDK found - please set JAVA_HOME"
		exit 1
	fi

	if [ ! -d "$CATALINA_BASE/conf" ]; then
		log_failure_msg "invalid CATALINA_BASE specified"
		exit 1
	fi

	log_daemon_msg "Starting $DESC" "$NAME"
	if start-stop-daemon --test --start --pidfile "$CATALINA_PID" \
		--user $TOMCAT5_USER --startas "$JAVA_HOME/bin/java" \
		>/dev/null; then

		# Clean up and set permissions on required files
		rm -rf "$CATALINA_BASE"/temp/*
		chown --dereference "$TOMCAT5_USER" "$CATALINA_BASE/conf" \
			"$CATALINA_BASE/conf/tomcat-users.xml" \
			"$CATALINA_BASE/logs" "$CATALINA_BASE/temp" \
			"$CATALINA_BASE/webapps" "$CATALINA_BASE/work" \
			"$CATALINA_BASE/logs/catalina.out" || true

		$DAEMON -user "$TOMCAT5_USER" -cp "$JSVC_CLASSPATH" \
		    -outfile "$LOGFILE"  -errfile '&1' \
		    -pidfile "$CATALINA_PID" $JAVA_OPTS "$BOOTSTRAP_CLASS"
	else
	        log_progress_msg "(already running)"
	fi
	log_end_msg 0
	;;
  stop)
	log_daemon_msg "Stopping $DESC" "$NAME"
        if start-stop-daemon --test --start --pidfile "$CATALINA_PID" \
		--user "$TOMCAT5_USER" --startas "$JAVA_HOME/bin/java" \
		>/dev/null; then
		log_progress_msg "(not running)"
	else
		$DAEMON -cp "$JSVC_CLASSPATH" -pidfile "$CATALINA_PID" \
		     -stop "$BOOTSTRAP_CLASS"
	fi
	log_end_msg 0
	;;
   status)
        if start-stop-daemon --test --start --pidfile "$CATALINA_PID" \
		--user $TOMCAT5_USER --startas "$JAVA_HOME/bin/java" \
		>/dev/null; then

		if [ -f "$CATALINA_PID" ]; then
		    log_success_msg "$DESC is not running, but pid file exists."
		    exit 1
		else
		    log_success_msg "$DESC is not running."
		    exit 3
		fi
	else
		log_success_msg "$DESC is running with pid `cat $CATALINA_PID`"
		exit 0
	fi
        ;;
  restart|force-reload)
        if start-stop-daemon --test --stop --pidfile "$CATALINA_PID" \
		--user $TOMCAT5_USER --startas "$JAVA_HOME/bin/java" \
		>/dev/null; then
		$0 stop
		sleep 1
	fi
	$0 start
	;;
  try-restart)
        if start-stop-daemon --test --start --pidfile "$CATALINA_PID" \
		--user $TOMCAT5_USER --startas "$JAVA_HOME/bin/java" \
		>/dev/null; then
		$0 start
	fi
        ;;
  *)
	log_success_msg "Usage: $0 {start|stop|restart|try-restart|force-reload|status}"
	exit 1
	;;
esac

exit 0
