#! /bin/sh

### BEGIN INIT INFO
# Provides:          codeflow
# Required-Start:    $local_fs $remote_fs $network
# Required-Stop:     $local_fs $remote_fs $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start CodeFlow Server
# Description:       This script provides a codeflow application
#                    server instance.
### END INIT INFO

# Source function library
. /lib/lsb/init-functions

NAME=codeflow
DESC="CodeFlow Application Server"
PATH=/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/opt/codeflow/bin/codeflow
PIDFILE=/opt/codeflow/var/$NAME.pid

test -x $DAEMON || exit 0

case "$1" in
    start)   /opt/codeflow/bin/codeflow -d; ;;
    stop)    /opt/codeflow/bin/codeflow -t; ;;
    restart) /opt/codeflow/bin/codeflow -r; ;;
    *)       log_success_msg "Usage: $0 {start|stop|restart}"; exit 1; ;;
esac

exit 0
