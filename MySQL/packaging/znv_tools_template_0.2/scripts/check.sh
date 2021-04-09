#! /bin/bash

cur_dir=$(cd `dirname $0`;pwd)
source ${cur_dir}/set_param.sh 
port=$1
basedir=${cur_dir}/..
#mysql=${SUB_MYSQL_BASE}/bin/mysql
#db_dir=${SUB_PREFIX_DATA_PATH}
haIgnore=${basedir}/config/ha.ignore
if [ -f ${haIgnore} ]; then
   exit 0
fi
flag=` cat ${db_dir}/var/${port}.pid |xargs ps -p|grep -v -i tty |wc -l`
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then 
	exit 0
else 
	exit 1
fi;
