#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh

msg_get_indices_failed="get indices from elasticsearch failed."
msg_get_aliases_failed="get aliases from elasticsearch failed."

( [ ! "${sync_es_http_ip}" ] || [ ! "${sync_es_http_port}" ] || [ ! "${cluster_name}" ] || [ ! -r "${list_file}" ] ) && echo "${pname_sync_es_http_ip} or ${pname_sync_es_http_port} or ${pname_cluster_name} or ${pname_list_file}  is null,exit 1 " && exit 1
real_cluster_name=`curl -X GET "${sync_es_http_ip}:${sync_es_http_port}/_cat/health?h=cluster"`
[ `check_between  "${cluster_name}" "${real_cluster_name}"` -eq 1 ] && echo "The real_cluster_name=${real_cluster_name} does not equal to cluster_name=${cluster_name} in config , exit 1. " && exit 1

indices=`es_execute "${sync_es_http_ip}"  "${sync_es_http_port}"  "GET"  "_cat/indices" "h=index"`
[ $? -ne 0 ] && echo msg_get_indices_failed && exit 1
aliases=`es_execute "${sync_es_http_ip}"  "${sync_es_http_port}"  "GET"  "_cat/aliases" "h=alias"`
[ $? -ne 0 ] && echo msg_get_aliases_failed && exit 1
while read index_file
do
index_name=`parse_index_name "${index_file}"`
action_name=`parse_action_name "${index_file}"`
if [ `echo "${action_name}X" |tr a-z A-Z` == "PUTX" ] ; then 
[ `check_between  ${index_name}  ${indices} ${aliases} ` -eq 0 ] && echo "thers has index_name=${index_name} in cluster , it must be not. " && exit 1
fi
done < ${list_file}
exit 0



