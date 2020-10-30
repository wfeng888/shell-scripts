#! /bin/bash

cpwd=$(cd `dirname $0`;pwd)
source $cpwd/predefine.sh
[  `check_between  ${os_user}  ${os_user_root}  ${os_user_mysql}` -eq 1 ]  && echo "execute user must be mysql or root ! " && exit 1;
os_user_mysql_group=`config_os_user ${os_user_mysql}`
[ ! "${os_user_mysql_group}" ] && echo "configure user ${os_user_mysql} failed.installing has not started!" && exit 1
[  `check_between  ${os_user}  ${os_user_mysql}` -eq 0  ] && command_prefix="sudo "
( [  ! ${running_mode} ] || [  ! ${running_mode} == ${running_mode_master_slave} ]  &&  [  ! ${running_mode} == ${running_mode_single} ] ) &&  echo "running_mode must in ${running_mode_master_slave} or ${running_mode_single} !" && exit 1 
( [  ! ${conn_username} ]  || [  ! ${project_name} ] || [  ! ${mysql_port} ]  || ( [  ! ${slave_hostip} ] && [  ${running_mode} == ${running_mode_master_slave} ] ) ) && echo " param   conn_username conn_userpwd project_name mysql_port  must not be null,or slave_hostip must not be null while running_mode is ${running_mode_master_slave} !" && exit 1;

echo "checking environment!"
check_port_busy "${mysql_port}"
[ $? -ne 0 ] && echo ${msg_port_busy} && exit 1
[ ! -f  "${cpwd}/${mysql_software_version}${file_suffix}"  ]  && echo "${cpwd}/${mysql_software_version}${file_suffix}""msg_file_not_found" && exit 1;
[ ! -f  "${cpwd}/${znvdata_version}${file_suffix}" ] && echo "${cpwd}/${znvdata_version}${file_suffix}""msg_file_not_found" && exit 1;
[ ! -f  "${cpwd}/${znv_tools_file}${file_suffix}" ] && echo "${cpwd}/${znv_tools_file}${file_suffix}""msg_file_not_found" && exit 1;
[ ! -d "${mysql_software_prefix}" ] && mkdir -p "${mysql_software_prefix}" && [ ! -d "${mysql_software_prefix}" ] && echo " mkdir ${mysql_software_prefix} failed,exit with wrong " && exit 1;
[ `check_between "${skip_mysql_software}" "R"  "S"` -eq 1 ] && echo "skip_mysql_software must be R or S ." && exit 1
if [ -d "${mysql_software_prefix}/${mysql_software_version}" ] ; then 
#	while( [ `check_between ${skip_mysql_software} "R" "S"` == 1 ] )
#	do
#		echo "${mysql_software_prefix}/${mysql_software_version} exists ,please decide what to do [S]kip or [R]eplace?"
#		msg_skip_mysql_software="Skip"
#		read skip_mysql_software
#	done;
	if [ `check_between "${skip_mysql_software}" "R"`  -eq 0  ] ; then 
	     msg_skip_mysql_software="Replace"
	     mv "${mysql_software_prefix}/${mysql_software_version}" "${mysql_software_prefix}/${mysql_software_version}.${cur_time}"
	fi;
fi;
[ -d "${mysql_data_path}" ] && echo "${mysql_data_path} has exists,please deal with this " && exit 1; 
#if [  `check_project_not_exist "${project_name}"` -ne 0 ] ; then 
#echo "project file ${projectFilePath}/${project_name}.mysql exists,we will replace it.Is this ok? Y/[N]"
#read r
#[  `echo "${r}X" |tr a-z A-Z `  != "YX" ] && exit 1
#fi;
exit 0