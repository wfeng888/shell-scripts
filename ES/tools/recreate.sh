#!/bin/bash
filepath=$1
http_host=$2
http_port=$3
delete_flag=$4
file=${filepath##*/}
index_name=`echo ${file##*#} |cut -d '.' -f 1`
oper_type=`echo $file|cut -d '#' -f 2`
is_template=`echo $file |grep 'template' `
template=
if [ ${is_template} ] ; then 
	template='_template/'		
fi
if [ "${delete_flag}X" == 'DELETEX' ] ; then
    echo "delete ${http_host}:${http_port}/${template}${index_name}"
    curl -X DELETE "${http_host}:${http_port}/${template}${index_name}?pretty"
else
    echo "deploy ${http_host}:${http_port}/${template}${index_name}"
    [ "${log_file}X" != "X" ] && echo "deploy ${http_host}:${http_port}/${template}${index_name}" >> ${log_file}
    index_name=`echo $index_name|tr @ /`
    ret=`curl -X $oper_type "${http_host}:${http_port}/${template}${index_name}?pretty" -H 'Content-Type: application/json' -d@${filepath}`
    echo $ret
    [ "${log_file}X" != "X" ] && echo $ret >> ${log_file}
    [ `echo $ret|grep  '"acknowledged" : true'|wc -l` -eq 0 ] && exit 1
fi
exit 0

