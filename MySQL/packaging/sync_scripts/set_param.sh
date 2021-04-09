#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/predefine.sh

pname_list_file="list_file"
pname_git_project_path="git_project_path"
pname_mysql_user="mysql_user"
pname_mysql_passwd="mysql_passwd"
pname_sync_ip="mysql_sync_ip"
pname_sync_port="mysql_sync_port"
pname_mysql_software_base="mysql_software_base"
pname_ignore_error="ignore_error"
pname_mysql_socket="mysql_socket"
pname_mysql_gz_software="mysql_gz_software"

list_file="${cur_dir}/`get_value  ${pname_list_file}  ${config_file}`"
git_project_path=`get_value ${pname_git_project_path}  ${config_file} `
if [[ ! ${git_project_path} =~ ^/ ]] ;then
git_project_path="${cur_dir}/${git_project_path}"
fi

type_string="TABLES;DML"
sortnum_delimiter="_"
mysql_user=`get_command_value "$1"  ${pname_mysql_user}  ${config_file}`
mysql_passwd=`get_command_value "$2"    ${pname_mysql_passwd}  ${config_file}`
mysql_sync_ip=`get_command_value "$3"    ${pname_sync_ip}  ${config_file}`
mysql_sync_port=`get_command_value "$4"    ${pname_sync_port}  ${config_file}`
mysql_software_base=`get_command_value "$5"    ${pname_mysql_software_base}  ${config_file}`
ignore_error=`get_command_value "$6"    ${pname_ignore_error}  ${config_file}`
mysql_socket=`get_command_value "$7"    ${pname_mysql_socket}  ${config_file}`
mysql_gz_software=`get_command_value  "$8"    ${pname_mysql_gz_software}  ${config_file}`
mysql="${mysql_software_base}/bin/mysql"
if ! [  -x "${mysql}"  -a  -f "${mysql}" ] ; then
	mysql_software_base="${cur_dir}/`echo ${mysql_gz_software##*/}|cut -d '.' -f 1-3`"
fi;

mysql="${mysql_software_base}/bin/mysql"
sqllog="${cur_dir}/exec-sql-log-${cur_time}.log"
login=`get_login_cmd "${mysql}"  "${mysql_user}" "${mysql_passwd}"  "${mysql_sync_ip}"  "${mysql_sync_port}" "${mysql_socket}"`
G_MODE_VALUE='VALUE'
G_MODE_GET='GET'