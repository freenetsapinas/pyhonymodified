#! /bin/sh
#
# squid3                Startup script for the SQUID HTTP proxy-cache.
#
# Version:      @(#)squid3.rc  1.0  07-Jul-2006  luigi@debian.org
#
### BEGIN INIT INFO
# Provides:          squid
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Should-Start:      $named
# Should-Stop:       $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Squid HTTP Proxy version 3.x
### END INIT INFO

NAME=squid
DESC="Squid HTTP Proxy 3.x"
DAEMON=/usr/sbin/squid
PIDFILE=/var/run/$NAME.pid
CONFIG=/etc/squid/squid.conf
SQUID_ARGS="-YC -f $CONFIG"

[ ! -f /etc/default/squid ] || . /etc/default/squid

. /lib/lsb/init-functions

PATH=/bin:/usr/bin:/sbin:/usr/sbin

[ -x $DAEMON ] || exit 0

ulimit -n 65535

find_cache_dir () {
        w="     " # space tab
        res=`sed -ne '
                s/^'$1'['"$w"']\+[^'"$w"']\+['"$w"']\+\([^'"$w"']\+\).*$/\1/p;
                t end;
                d;
                :end q' < $CONFIG`
        [ -n "$res" ] || res=$2
        echo "$res"
}

find_cache_type () {
        w="     " # space tab
        res=`sed -ne '
                s/^'$1'['"$w"']\+\([^'"$w"']\+\).*$/\1/p;
                t end;
                d;
                :end q' < $CONFIG`
        [ -n "$res" ] || res=$2
        echo "$res"
}

start () {
        cache_dir=`find_cache_dir cache_dir`
        cache_type=`find_cache_type cache_dir`

        #
        # Create spool dirs if they don't exist.
        #
        if [ "$cache_type" = "coss" -a -d "$cache_dir" -a ! -f "$cache_dir/stripe" ] || [ "$cache_type" != "coss" -a -d "$cache_dir" -a ! -d "$cache_dir/00" ]
        then
                log_warning_msg "Creating $DESC cache structure"
                $DAEMON -z -f $CONFIG
        fi

        umask 027
        ulimit -n 65535
        cd $cache_dir
        start-stop-daemon --quiet --start \
                --pidfile $PIDFILE \
                --exec $DAEMON -- $SQUID_ARGS < /dev/null
        return $?
}

stop () {
        PID=`cat $PIDFILE 2>/dev/null`
        start-stop-daemon --stop --quiet --pidfile $PIDFILE --exec $DAEMON
        #
        #       Now we have to wait until squid has _really_ stopped.
        #
        sleep 2
        if test -n "$PID" && kill -0 $PID 2>/dev/null
        then
                log_action_begin_msg " Waiting"
                cnt=0
                while kill -0 $PID 2>/dev/null
                do
                        cnt=`expr $cnt + 1`
                        if [ $cnt -gt 24 ]
                        then
                                log_action_end_msg 1
                                return 1
                        fi
                        sleep 5
                        log_action_cont_msg ""
                done
                log_action_end_msg 0
                return 0
        else
                return 0
        fi
}

case "$1" in
    start)
        log_daemon_msg "Starting $DESC" "$NAME"
        if start ; then
                log_end_msg $?
        else
                log_end_msg $?
        fi
        ;;
    stop)
        log_daemon_msg "Stopping $DESC" "$NAME"
        if stop ; then
                log_end_msg $?
        else
                log_end_msg $?
        fi
        ;;
    reload|force-reload)
        log_action_msg "Reloading $DESC configuration files"
        start-stop-daemon --stop --signal 1 \
                --pidfile $PIDFILE --quiet --exec $DAEMON
        log_action_end_msg 0
        ;;
    restart)
        log_daemon_msg "Restarting $DESC" "$NAME"
        stop
        if start ; then
                log_end_msg $?
        else
                log_end_msg $?
        fi
        ;;
    status)
        status_of_proc -p $PIDFILE $DAEMON $NAME && exit 0 || exit 3
        ;;
    *)
        echo "Usage: /etc/init.d/$NAME {start|stop|reload|force-reload|restart|status}"
        exit 3
        ;;
esac

exit 0