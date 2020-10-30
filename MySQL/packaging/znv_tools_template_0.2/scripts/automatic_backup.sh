#! /bin/bash
port=$1
cpwd=$(cd `dirname $0`; pwd)
. ${cpwd}/writelog.sh "${cpwd}/backup.sh" "$port" "from $0"
