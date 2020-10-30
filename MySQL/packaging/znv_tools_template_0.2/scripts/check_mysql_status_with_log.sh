#! /bin/bash
port=$1
cpwd=$(cd `dirname $0`; pwd)
. ${cpwd}/writelog.sh  "${cpwd}/check_mysql_status.sh" "${port}"  " from $0"
