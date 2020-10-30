#! /bin/bash
port=$1
cpwd=$(cd `dirname $0`; pwd)
. ${cpwd}/writelog.sh "${cpwd}/switch.sh" "$port" "TO_BACKUP" "from $0"
