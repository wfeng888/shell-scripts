#! /bin/bash
cur_dir=$(cd `dirname $0`;pwd)
source ${cur_dir}/predefine.sh


#pname_project_name="project_name"
pname_base_dir="base_dir"
pname_network_host="network_host"
pname_http_host="http_host"
pname_http_port="http_port"
pname_transport_host="transport_host"
pname_transport_tcp_port="transport_tcp_port"
pname_heap_size="heap_size"
pname_running_mode="running_mode"
pname_package_name="package_name"
pname_cluster_name="cluster_name"
pname_es_version="es_version"
pname_git_project_path="git_project_path"


#project_name=`get_value ${pname_project_name}  ${config_file} `
base_dir=`get_value ${pname_base_dir}  ${config_file} `
network_host=`get_value ${pname_network_host}  ${config_file} `
http_host=`get_value ${pname_http_host}  ${config_file} `
http_port=`get_value ${pname_http_port}  ${config_file} `
transport_host=`get_value ${pname_transport_host}  ${config_file} `
transport_tcp_port=`get_value ${pname_transport_tcp_port}  ${config_file} `
heap_size=`get_value ${pname_heap_size}  ${config_file} `
package_name=`get_value ${pname_package_name}  ${config_file} `
cluster_name=`get_value ${pname_cluster_name}  ${config_file} `
es_version=`get_value ${pname_es_version}  ${config_file} `
git_project_path=`get_value ${pname_git_project_path}  ${config_file} `
if [[ ! ${git_project_path} =~ ^/ ]] ;then
git_project_path="${base_dir}/${git_project_path}"
fi
tmp_work_dir="${base_dir}/${cur_time}"

running_mode=SINGLE
type_string="TEMPLATE;INDEX"
sortnum_delimiter="#"

os_user_es="elasticsearch"
os_user_group_es="elastic"
os_user_root="root"
cur_user=`id -un`
package_gz_file=$package_name".tar"