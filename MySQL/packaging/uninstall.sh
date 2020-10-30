#!/bin/bash

cpwd=$(cd `dirname $0`;pwd)
source ${cpwd}/predefine.sh
project_file=${projectFilePath}/${SUB_PROJECT_NAME}

sh ${cpwd}/stop.sh
systemctl disable mysql_${mysql_port}.service

content=`cat ${project_file}`
mysqlsoftwarepath=`parse_param "${content}" "${pname_mysqlsoftwarepath}"`
mysqlDataPath=`parse_param "${content}" "${pname_mysqlDataPath}"`

if  test -x ${mysqlDataPath} 
then 
    mv ${mysqlDataPath} ${mysqlDataPath}.${cur_time}
fi
exit 0