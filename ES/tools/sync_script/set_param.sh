#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/predefine.sh


pname_sync_es_http_ip="sync_es_http_ip"
pname_sync_es_http_port="sync_es_http_port"
pname_cluster_name="cluster_name"
pname_list_file="list_file"
pname_git_project_path="git_project_path"

sync_es_http_ip=`get_value  ${pname_sync_es_http_ip}  ${config_file}`
sync_es_http_port=`get_value  ${pname_sync_es_http_port}  ${config_file}`
cluster_name=`get_value  ${pname_cluster_name}  ${config_file}`
list_file="${cur_dir}/`get_value  ${pname_list_file}  ${config_file}`"
git_project_path=`get_value ${pname_git_project_path}  ${config_file} `
if [[ ! ${git_project_path} =~ ^/ ]] ;then
git_project_path="${cur_dir}/${git_project_path}"
fi

type_string="TEMPLATE;INDEX"
sortnum_delimiter="#"