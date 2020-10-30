#!/bin/bash
cpwd=$(cd `dirname $0`; pwd)
pidfile=${cpwd}/../var/keepalived.pid
if [ -f ${pidfile} ]; then
  kill -TERM `cat ${pidfile}` && rm -f ${pidfile}
fi
