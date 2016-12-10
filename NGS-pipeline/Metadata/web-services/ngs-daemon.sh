#!/bin/bash
option=$1

# script to daemonize the ngsserver application
# use it as any daemon script e.g.
# ./ngs-daemon.sh start|stop|restart|status
name="NGS_SERVER"




port=8082
command=$(dirname $(readlink -f $0 ) )"/ngs-db.server.pl"
command_args="--forcePort ${port} --logfile ngs-server.${port}.log"
daemon="/usr/bin/daemon"

[ -x "$daemon" ] || exit 0
[ -x "$command" ] || exit 0
# Any command line arguments for the daemon executable (when starting)
daemon_start_args="" # e.g. --inherit --env="ENV=VAR" --unsafe
# The pidfile directory (need to force this so status works for normal users)
pidfiles=$(dirname $command)
# The user[:group] to run as (if not to be run as root)
user=""
# The path to chroot to (otherwise /)
chroot=""
# The path to chdir to (otherwise /)
chdir="$(dirname $command)"
# The umask to adopt, if any
umask=""
# The syslog facility or filename for the client's stdout (otherwise discarded)
stdout="daemon.info"
# The syslog facility or filename for the client's stderr (otherwise discarded)
stderr="daemon.err"

case "$option" in
    start)
        # This if statement isn't strictly necessary but it's user friendly
        if "$daemon" --running --name "$name" --pidfiles "$pidfiles"
        then
            echo "$name is already running."
        else
            echo -n "Starting $name..."
            "$daemon" --respawn $daemon_start_args \
                --name "$name" --pidfiles "$pidfiles" \
                ${user:+--user $user} ${chroot:+--chroot $chroot} \
                ${chdir:+--chdir $chdir} ${umask:+--umask $umask} \
                ${stdout:+--stdout $stdout} ${stderr:+--stderr $stderr} \
                -- \
                "$command" $command_args
            echo done.
        fi
        ;;

    stop)
        # This if statement isn't strictly necessary but it's user friendly
        if "$daemon" --running --name "$name" --pidfiles "$pidfiles"
        then
            echo -n "Stopping $name..."
            "$daemon" --stop --name "$name" --pidfiles "$pidfiles"
            echo done.
        else
            echo "$name is not running."
        fi
        ;;

    restart|reload)
        if "$daemon" --running --name "$name" --pidfiles "$pidfiles"
        then
            echo -n "Restarting $name..."
            "$daemon" --restart --name "$name" --pidfiles "$pidfiles"
            echo done.
        else
            echo "$name is not running."
            exit 1
        fi
        ;;

    status)
        "$daemon" --running --name "$name" --pidfiles "$pidfiles" --verbose
        ;;

    *)
        echo "usage: $0 <start|stop|restart|reload|status>" >&2
        exit 1
esac

exit 0
