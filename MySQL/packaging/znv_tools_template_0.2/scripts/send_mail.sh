#! /bin/bash
cpwd=$(cd `dirname $0`; pwd)
. ${cpwd}/writelog.sh "${cpwd}/send_mail.pl" "$@" " from $0 "
