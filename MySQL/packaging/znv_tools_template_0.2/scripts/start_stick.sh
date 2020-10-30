#!/bin/bash
cpwd=$(cd `dirname $0`; pwd)
basedir=${cpwd}/..
keepalived  --use-file=${basedir}/config/keepalived.conf --log-detail  --log-file=${basedir}/log/keepalived.log --flush-log-file --pid=${basedir}/var/keepalived.pid --vrrp_pid=${basedir}/var/keepalived_vrrp.pid  --checkers_pid=${basedir}/var/keepalived_check.pid  
