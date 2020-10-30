#! /bin/bash
port=$1
cpwd=$(cd `dirname $0`; pwd)
. ${cpwd}/writelog.sh  "${cpwd}/switch.sh" "$port" "TO_MASTER" " from $0" 
