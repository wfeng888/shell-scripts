#! /bin/bash
{
cpwd=$(cd `dirname $0`; pwd)
ctime=`date '+%Y-%m-%d %H:%M:%S'`
echo "execute $@ on $ctime"
"$@"
echo " "
} >> ${cpwd}/../log/run.log 2>&1
