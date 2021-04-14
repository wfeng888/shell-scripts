#! /bin/bash


#functions
get_param_value(){
#$1 param_name
#$2 cofig_file_name
local param_row
echo `grep -o -E ^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[0-9.a-zA-Z_/-]+[[:blank:]]*  $2|cut -d '=' -f 2`
}

get_param_value_with_default(){
#$1 param_name
#$2 cofig_file_name
#$3 defalut value
local pvalue=`get_param_value $1 $2`
pvalue=${pvalue:=$3}
echo ${pvalue}
}

replace_param(){
#3 org_file
#4 tar_file
cat $1 |sed -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_BACKUP_BASE}:'${backup_base}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_KEEPALIVED_BASE}:'"$mysql_data_path/../"':g' -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_PROJECT_NAME}:'${project_name}':g'  -e 's:${SUB_VIP}:'${vip}':g' > $2
}

check_mysql(){
#1 mysqlpath
#2 conn_user
#3 socket
#4 usepwd
local flag
local mysql=$1
local user=$2
local socket=$3
local usepwd=` [ $4 ] && echo "-p$4" ` 
flag=`${mysql} -u${user} ${usepwd}  --socket=${socket} -e " select 1 flag;"|grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo 0
else
        echo 1
fi;
}


has_slave_host(){
local mysql=$1
local loginpath=$2
local flag=1
[ `$mysql --login-path=${loginpath} -u${ops_username}  -e "show slave hosts  \G " |grep 'Server_id'|sed "s/ \{1,\}//g"|cut -d ":" -f 2 ` ] && flag=0
echo $flag
}



common_waittimeout(){
#1 timeout
#2 other
local waittime=0
local timeout=$1
shift
while (( "${waittime} < ${timeout}" ))
do
echo "check loop count:$[waittime/5]"
[ `$@` -eq 0 ] && return 0 
sleep 5
let "waittime+=5"
done
return 1
}

waittimeout_until_has_slave_host(){
#1 timeout
#2 mysqlbinpath
#3 login-path
common_waittimeout "$1" "has_slave_host" "$2" "$3"
}

check_mysql_until_timeout(){
#1 mysqlpath
#2 conn_user
#3 socket
#4 usepwd
#5 times
local waittime=0
local timeout=$5
while (( "${waittime} < ${timeout}" ))
do
echo "check loop count:$[waittime/5]"
[ `check_mysql "$1"  "$2"  "$3"  "$4"` -eq 0 ] && return 0 
sleep 5
let "waittime+=5"
done
return 1
}



create_opsuser(){
#1 mysqlpath
#2 conn_user
#3 socket
#4 usepwd
#5 success
#6 fail
#7 tips
#8 sql_scripts
#9 c_username
#10 c_userpwd
#11 hostip
#12 port
local mysql=$1
local user=$2
local socket=$3
local usepwd=` [ $4 ] && echo "-p$4" ` 
local flag= 
echo $7
${mysql} -u${user} ${usepwd}  --socket=${socket} -f <<!
${8}
!
if [  "${11}" ] ; then 
flag=`${mysql} -u${9} -p${10}  --host=${11} -P${12} --protocol=tcp -e " select 1 flag;"|grep -v flag `
else
flag=`${mysql} -u${9} -p${10}  --socket=${socket} -e " select 1 flag;"|grep -v flag `
fi;

flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo $5
else
        echo $6
fi;
}

execute_sql(){
#1 mysqlpath
#2 conn_user
#3 socket
#4 usepwd
#5 sql_script
local mysql=$1
local user=$2
local socket=$3
local usepwd=` [ $4 ] && echo "-p$4" ` 

${mysql} -u${user} ${usepwd}  --socket=${socket} -N -f <<!
${5}
!
}

check_mysql_by_loginpath(){
#1 mysqlpath
#2 pathName
#3 socket
local mysql=$1
local login_path=$2
local flag=
flag=`$mysql --login-path=${login_path} -u${ops_username} -e " select 1 flag;"|grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo 0
else
        echo 1
fi;
}

check_loginpath_untiltimeout(){
#1 mysqlpath
#2 pathName
#3 timeout
local timeout=$3
local waittime=0
while (( "${waittime} < ${timeout}" ))
do
echo "login path had not configured properly , please do it . check loop count:$[waittime/5]"
[ `check_mysql_by_loginpath "$1" "$2" ` -eq 0 ] && return 0
sleep 5
let "waittime+=5"
done
return 1
}


check_between(){
local i=1
first_param=
[ ! $1 ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return;
let "i+=1"
done
echo 1
}

configure_login_path(){
#1 mysql_bin_path
#2 user
#3 socket
#4 pwd
#5 port
#6 tips
#7 success
#8 fail
#9 exists
local mysql_bin_path=$1
local user=$2
local socket=$3
local pwd=$4
local port=$5
local choice=
echo $6
if [  `"${mysql_bin_path}/bin/mysql_config_editor" print -G${port}|wc -l` -gt 1 ] ;then 
	echo $9
	echo "please make a choice ,[S]kip or [R]pace ?"
	read choice
	if [ `check_between  ${choice} "S" ` -eq 0 ] ; then 
		echo "skip configure login path"
	    return;
	else 
		echo "replace login path"
		"${mysql_bin_path}/bin/mysql_config_editor" remove -G${port}
	fi;
fi;
echo "Please input ${pwd} "
"${mysql_bin_path}/bin/mysql_config_editor"  set --login-path=${port}   --socket=${socket}  --password


if [ `check_mysql_by_loginpath  "${mysql_bin_path}/bin/mysql"  "${port}" ` -eq 0 ] ; then 
	echo $7
	return 0
else 
	echo $8
	return 1
fi;
}


configure_login_path_until_timeout(){
#1 timeout 
#2 other parameters reference function configure_login_path
common_waittimeout_by_returncode "$1"  "configure_login_path"  "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" 
[ $? -ne 0 ] && echo $10
}


common_waittimeout_by_returncode(){
#1 timeout
#2 other
local waittime=0
local timeout=$1
shift
while (( "${waittime} < ${timeout}" ))
do
echo "check loop count:$[waittime/5]"
$@ 
[ $? -eq 0 ]  && return 0 
sleep 5
let "waittime+=5"
done
return 1
}


#0 2 * * * sh /data/keepalived/scripts/automatic_backup.sh  >> /data/keepalived/log/run.log 2>&1
#*/10 * * * * sh /data/keepalived/scripts/check_mysql_status_with_log.sh  >> /data/keepalived/log/run.log 2>&1
configure_cron(){
#1 cron_expression
#2 script
#3 tips
#4 success
#5 has_exists
#6 fail
#7 logfile
echo $3
[ `grep "${2}" /var/spool/cron/${os_user}|wc -l` -eq 1 ] && echo $5 && return
echo "$1 sh ${2} >> ${7} 2>&1 " >> /var/spool/cron/${os_user} 
[ $? -eq 0  ] && echo $4 && return
echo $6
}


check_mysql_process(){
#1 port
[ `ps -ef|grep -w  mysqld|grep ${1}|wc -l` -eq 0 ] && echo 0 && return 
echo 1
}

check_mysql_down_untiltimeout(){
#1 port
#2 times
local waittime=0
local timeout=$2
while (( "${waittime} < ${timeout}" ))
do
echo "check loop count:$[waittime/5]"
[ `check_mysql_process "$1"` -eq 0 ] && return 0 
sleep 5
let "waittime+=5"
done
return 1
}

shutdown_mysql(){
local mysql=$1
local user=$2
local socket=$3
local usepwd=` [ $4 ] && echo "-p$4" `
local port=$5
local timeout=30
${mysql} -u${user} ${usepwd}  --socket=${socket} <<!
shutdown;
!
check_mysql_down_untiltimeout  "${port}" "${timeout}"
}


config_os_user(){
#1 os_user_name
#return user_group
local os_user=$1
#local user_mysql_exist=`grep -E "^${os_user}:"  /etc/passwd|wc -l`
#local os_group_mysql_id=`grep -E "^${os_user}:"  /etc/passwd|cut -d ':' -f 4`
#local os_group_mysql=`grep -E "^[A-Za-z0-9]*:[A-Za-z0-9]*:${os_group_mysql_id}:" /etc/group|cut -d ':' -f 1`
local user_exist=`id -un ${os_user}`
local user_group=`id -ng ${os_user}`
[ "${user_exist}x" == "${os_user}x" ] && echo "${user_group}" && return 0
mkdir -p "/home/${os_user}"
useradd -d "/home/${os_user}" -U  -s "/bin/bash"  -p "${os_user}" "${os_user}"
chown "${os_user}":"${os_user}" "/home/${os_user}"
echo "${os_user}" && return 0
}

check_project_not_exist(){
#1 projectname
local projectname=$1
[ ! -f  "${projectFilePath}/${projectname}.mysql" ] && echo  0 && return 0
echo 1
}

mk_project_file(){
#1  projectName
#2  mysqlSoftwarePath
#3  mysqlDataPath
local projectname=$1
local mysqlsoftwarepath=$2
local mysqldatapath=$3
[ ! -d "${projectFilePath}" ] && mkdir "${projectFilePath}"
[ -f "${projectFilePath}/${projectname}.mysql" ] && mv "${projectFilePath}/${projectname}.mysql"  "${projectFilePath}/${projectname}.mysql.${cur_time}"
echo "projectName=${projectname};mysqlSoftwarePath=${mysqlsoftwarepath};mysqlDataPath=${mysqldatapath}; "> "${projectFilePath}/${projectname}.mysql" 
echo $? 
}

config_mysql_service(){
systemctl disable mysql_${mysql_port}.service > /dev/null 2>&1
cp -f ${mysql_data_path}/znvtools/scripts/mysql.service  /usr/lib/systemd/system/mysql_${mysql_port}.service
systemctl enable mysql_${mysql_port}.service
systemctl start mysql_${mysql_port}.service
}

config_keepalived_service(){
systemctl disable keepalived_${mysql_port}.service > /dev/null 2>&1
cp -f ${mysql_data_path}/znvtools/scripts/keepalived.service  /usr/lib/systemd/system/keepalived_${mysql_port}.service
systemctl enable keepalived_${mysql_port}.service
systemctl start keepalived_${mysql_port}.service
}

check_port_busy(){
#1 mysql_port
[ `netstat -apn|grep -w ${1}|wc -l ` -gt 0 ] && return 1
return 0
}

projectFilePath="/etc/znvTab"
cpwd=$(cd `dirname $0`; pwd)
version_file=${cpwd}/version.lst
config_file=${cpwd}/config.param
file_suffix=".tar.gz"
pname_mysql_port="mysql_port"
#pname_mysql_software_base="mysql_software_base"
pname_mysql_data_path="mysql_data_base"
#pname_keepalived_base="keepalived_base"
pname_slave_hostip="slave_hostip"
pname_master_hostip="master_hostip"
pname_backup_base="backup_base"
pname_vip="vip"
pname_mysql_software_version="mysql_software_version"
pname_znvdata_version="znvdata_version"
pname_project_name="project_name"
pname_repl_username="repl_username"
pname_repl_userpwd="repl_userpwd"
pname_conn_username="conn_username"
pname_conn_userpwd="conn_userpwd"
pname_mode="running_mode"
pname_mysql_software_prefix="mysql_software_prefix"
pname_znv_tools_file="znv_tools_template"
pname_application_username="application_username"
pname_application_userpasswd="application_userpasswd"
pname_backup_software_gzpath="backup_software_gzpath"

msg_file_not_found=" file not found.please check! "
msg_auto_backup_tip="configure auto backup..."
msg_auto_backup_ok="cofigure auto backup success."
msg_auto_backup_exists="auto backup had been deployed,doing nothing.you shoud be confirm later."
msg_auto_backup_fail="there has something wrong with deploying auto backup,please check later."
msg_replication_check_tip="configure replication check..."
msg_replication_check_ok="cofigure auto backup success."
msg_replication_check_exists="auto backup had been deployed,doing nothing.you shoud be confirm later."
msg_replication_check_fail="there has something wrong with deploying auto backup,please check later."
msg_login_path_tip="configure_login_path..."
msg_login_path_ok="configure_login_path_success."
msg_login_path_exists="login_path_has_been_configured,what_do_you_want_to_do?"
msg_login_path_fail="configure_login_path_failed."
msg_create_opsuer_success="ops user create success;"
msg_create_opsuer_fail="ops user create failed;"
msg_create_opsuer_tip="create ops user..."
msg_create_repl_success="replication user create success;"
msg_create_repl_fail="replication user create failed;"
msg_create_repl_tip="replication ops user..."


msg_create_app_user_success="application user create success;"
msg_create_app_user_fail="application user create failed;"
msg_create_app_user_tip="configure application user..."



cron_expression_backup="0 2 * * *"
cron_expression_replication_check="*/10 * * * *"
default_software_prefix="/usr/local/znv"
default_repl_username="znvrepl"
default_repl_userpwd="znvrepl"
default_conn_username="root"
default_conn_userpwd=
default_application_username="dcvsopr"
default_application_userpwd="dcvsopr_passwd"
default_znv_tools_template="znv_tools_template"
ops_username="autoOPS"
ops_password="b8Ax@^.,0"


mysql_port=`get_param_value ${pname_mysql_port}  ${config_file} `
#mysql_software_base=`get_param_value ${pname_mysql_software_base}  ${config_file} `
mysql_data_base=`get_param_value ${pname_mysql_data_path}  ${config_file} `
#keepalived_base=`get_param_value ${pname_keepalived_base}  ${config_file} `
slave_hostip=`get_param_value ${pname_slave_hostip}  ${config_file} `
master_hostip=`get_param_value ${pname_master_hostip}  ${config_file} `
backup_base=`get_param_value ${pname_backup_base}  ${config_file} `
vip=`get_param_value ${pname_vip}  ${config_file} `
mysql_software_version=`get_param_value ${pname_mysql_software_version}  ${version_file} `
znvdata_version=`get_param_value ${pname_znvdata_version}  ${version_file} `
project_name=`get_param_value ${pname_project_name}  ${config_file} `
cur_time=`date +%Y-%m-%d-%H-%M-%S`

mysql_software_prefix=`get_param_value_with_default ${pname_mysql_software_prefix}  ${version_file} ${default_software_prefix} `
mysql_data_path=`echo "${mysql_data_base}/my${mysql_port}/${znvdata_version}" `
repl_username=`get_param_value_with_default ${pname_repl_username}  ${config_file} ${default_repl_username}`
repl_userpwd=`get_param_value_with_default ${pname_repl_userpwd}  ${config_file} ${default_repl_userpwd}`
conn_username=`get_param_value_with_default ${pname_conn_username}  ${config_file} ${default_conn_username}`
conn_userpwd=`get_param_value ${pname_conn_userpwd}  ${config_file} `
running_mode=`get_param_value ${pname_mode}  ${config_file} `
znv_tools_file=`get_param_value_with_default ${pname_znv_tools_file}  ${version_file} ${default_znv_tools_template}`
application_username=`get_param_value_with_default ${pname_application_username}  ${config_file} ${default_application_username}`
application_userpasswd=`get_param_value_with_default ${pname_application_userpasswd}  ${config_file} ${default_application_userpwd}`
backup_software_gzpath=`get_param_value ${pname_backup_software_gzpath} ${config_file}`
running_mode_master_slave="MASTER_SLAVE"
running_mode_single="SINGLE"
use_pwd=
keepalived_master="BACKUP"
keepalived_backup="BACKUP"
keepalived_master_priority=90
keepalived_backup_priority=90
tmp_dir=${cpwd}/${cur_time}
master_server_id=1
slave_server_id=2
master_read_only=OFF
slave_read_only=ON
#[  ${running_mode} == ${running_mode_single} ] &&  master_read_only='OFF'
master_event_scheduler=1
slave_event_scheduler=0
skip_mysql_software=
msg_skip_mysql_software=
slave_has_errors=
os_user=`id -un`
command_prefix=
os_user_root="root"
os_user_mysql="mysql"
os_user_mysql_group=

msg_port_busy="mysql port ${mysql_port} you configured must be busy,deal with this or using another port!"

[  `check_between  ${os_user}  ${os_user_root}  ${os_user_mysql}` -eq 1 ]  && echo "execute user must be mysql or root ! " && exit 1;
os_user_mysql_group=`config_os_user ${os_user_mysql}`
[ ! "${os_user_mysql_group}" ] && echo "configure user ${os_user_mysql} failed.installing has not started!"
[  `check_between  ${os_user}  ${os_user_mysql}` -eq 0  ] && command_prefix="sudo "
( [  ! ${running_mode} ] || [  ! ${running_mode} == ${running_mode_master_slave} ]  &&  [  ! ${running_mode} == ${running_mode_single} ] ) &&  echo "running_mode must in ${running_mode_master_slave} or ${running_mode_single} !" && exit 1 
( [ ! ${repl_username} ] || [  ! ${repl_userpwd} ] || [  ! ${conn_username} ]  || [  ! ${project_name} ] || [  ! ${mysql_port} ] || [  ! ${master_hostip} ] || ( [  ! ${slave_hostip} ] && [  ${running_mode} == ${running_mode_master_slave} ] ) ) && echo " param repl_username repl_userpwd conn_username conn_userpwd project_name mysql_port master_hostip must not be null,or slave_hostip must not be null while running_mode is ${running_mode_master_slave} !" && exit 1;

echo "checking environment!"
check_port_busy "${mysql_port}"
[ $? -ne 0 ] && echo ${msg_port_busy} && exit 1
[ ! -f  "${cpwd}/${mysql_software_version}${file_suffix}"  ]  && echo "${cpwd}/${mysql_software_version}${file_suffix}""msg_file_not_found" && exit 1;
[ ! -f  "${cpwd}/${znvdata_version}${file_suffix}" ] && echo "${cpwd}/${znvdata_version}${file_suffix}""msg_file_not_found" && exit 1;
[ ! -f  "${cpwd}/${znv_tools_file}${file_suffix}" ] && echo "${cpwd}/${znv_tools_file}${file_suffix}""msg_file_not_found" && exit 1;
[ ! -d "${mysql_software_prefix}" ] && mkdir -p "${mysql_software_prefix}" && [ ! -d "${mysql_software_prefix}" ] && echo " mkdir ${mysql_software_prefix} failed,exit with wrong "
if [ -d "${mysql_software_prefix}/${mysql_software_version}" ] ; then 
	while( [ `check_between ${skip_mysql_software} "R" "S"` == 1 ] )
	do
		echo "${mysql_software_prefix}/${mysql_software_version} exists ,please decide what to do [S]kip or [R]eplace?"
		msg_skip_mysql_software="Skip"
		read skip_mysql_software
	done;
	if [ `check_between "${skip_mysql_software}" "R"`  -eq 0  ] ; then 
	     msg_skip_mysql_software="Replace"
	     mv "${mysql_software_prefix}/${mysql_software_version}" "${mysql_software_prefix}/${mysql_software_version}.${cur_time}"
	fi;
fi;
[ -d "${mysql_data_path}" ] && echo "${mysql_data_path} has exists,please deal with this " && exit 1; 
if [  `check_project_not_exist "${project_name}"` -ne 0 ] ; then 
echo "project file ${projectFilePath}/${project_name}.mysql exists,we will replace it.Is this ok? Y/[N]"
read r
[  `echo "${r}X" |tr a-z A-Z `  != "YX" ] && exit 1
fi;

if [ ${running_mode} == ${running_mode_master_slave} ] ; then 
echo '
#! /bin/bash
check_between(){
local i=1
first_param=
[ ! $1 ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return;
let "i+=1"
done
echo 1
}

config_os_user(){
#1 os_user_name
#return user_group
local os_user=$1
#local user_mysql_exist=`grep -E "^${os_user}:"  /etc/passwd|wc -l`
#local os_group_mysql_id=`grep -E "^${os_user}:"  /etc/passwd|cut -d ':' -f 4`
#local os_group_mysql=`grep -E "^[A-Za-z0-9]*:[A-Za-z0-9]*:${os_group_mysql_id}:" /etc/group|cut -d ':' -f 1`
local user_exist=`id -un ${os_user}`
local user_group=`id -ng ${os_user}`
[ "${user_exist}x" == "${os_user}x" ] && echo "${user_group}" && return 0
mkdir -p "/home/${os_user}"
useradd -d "/home/${os_user}" -U  -s "/bin/bash"  -p "${os_user}" "${os_user}"
chown "${os_user}":"${os_user}" "/home/${os_user}"
echo "${os_user}" && return 0
}

check_project_not_exist(){
#1 projectname
local projectname=$1
[ ! -f  "${projectFilePath}/${projectname}.mysql" ] && echo  0 && return 0
echo 1
}
check_port_busy(){
#1 mysql_port
[ `netstat -apn|grep -w ${1}|wc -l ` -gt 0 ] && return 1
return 0
}

' > execute_check_for_slave.sh

cat >> execute_check_for_slave.sh << foe
os_user_mysql=${os_user_mysql}
slave_host_ip=${slave_hostip}
project_name=${project_name}
projectFilePath=${projectFilePath}
mysql_data_path=${mysql_data_path}
mysql_software_prefix=${mysql_software_prefix}
mysql_software_version=${mysql_software_version}
mysql_port="${mysql_port}"
msg_port_busy="${msg_port_busy}"
[ ! -d "${mysql_software_prefix}" ] && mkdir -p "${mysql_software_prefix}"  ;
if [ -d "${mysql_software_prefix}/${mysql_software_version}" ] ; then 
    if [  ${skip_mysql_software} ] ; then 
		echo "${mysql_software_prefix}/${mysql_software_version} exists , we will do what you had choice on master ${msg_skip_mysql_software}.You need be sure"
		if [  `check_between "${skip_mysql_software}" "R"`  -eq 0  ] ; then 
		   mv "${mysql_software_prefix}/${mysql_software_version}" "${mysql_software_prefix}/${mysql_software_version}.${cur_time}"
		fi;
	else
	    echo "${mysql_software_prefix}/${mysql_software_version} exists, we do not know what you want to do. Please set mysql_software_prefix a different value in config file." && exit 1;
	fi;
fi;
[ -d "${mysql_data_path}" ] && echo " slave host ${mysql_data_path} has exists,please deal with this "  && exit 1  ;
foe
echo '

check_port_busy "${mysql_port}"
[ $? -ne 0 ] && echo ${msg_port_busy} && exit 1
[ `check_project_not_exist "${project_name}"` -ne 0 ] && echo "project file ${projectFilePath}/${project_name}.mysql exists,we will replace it.You need be sure !"

os_user_mysql_group_slave=`config_os_user ${os_user_mysql}`
echo "os_user_mysql_group_slave is ${os_user_mysql_group_slave}"
[ ! "${os_user_mysql_group_slave}" ] && echo "configure os user ${os_user_mysql} on slave host ${slave_host_ip} failed,installing will not success with this . Please deal " && exit 1 ;

echo "slave host environment check ok,continuing "
exit 0;
' >> execute_check_for_slave.sh

scp execute_check_for_slave.sh  ${os_user}@${slave_hostip}:/tmp/
echo "check environment  on slave host!"
ssh -t -t ${os_user}@${slave_hostip} bash -i -s <<!
sh -i  /tmp/execute_check_for_slave.sh
exit 
!
fi;

echo "please confirm everything is ok? Y/[N]"
read confirm
if [ ! ${confirm}x = "Yx" ] && [ ! ${confirm}x = "yx"  ] ; then 
exit 1;
fi;

echo "generate install files!"

if [  `check_between "${skip_mysql_software}" "S"`  -eq 1 ] ; then 
	echo "unzip mysql software files !"
	tar -xzpvf "${cpwd}/${mysql_software_version}${file_suffix}" 
	echo "install mysql software files !"
    mv "${cpwd}/${mysql_software_version}"  "${mysql_software_prefix}/"
fi;
echo "unzip mysql database files !"
tar -xzpvf "${cpwd}/${znvdata_version}${file_suffix}" > /dev/null 2>&1 ;
echo "install mysql database files !"
mysql_data_path_tmp=${mysql_data_path%/*}
mkdir -p ${mysql_data_path_tmp}
mv "${znvdata_version}"  "${mysql_data_path_tmp}"
tar -xzpvf "${cpwd}/${znv_tools_file}${file_suffix}"
cd "./${znv_tools_file}"
mkdir -p ${tmp_dir}/znvtools/config
mkdir -p ${tmp_dir}/znvtools/log
mkdir -p ${tmp_dir}/znvtools/var
mkdir -p ${tmp_dir}/znvtools/scripts
cat ./config/keepalived.conf |sed -e 's:${SUB_KEEPALIVED_BASE}:'"$mysql_data_path"':g' -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_KEEPALIVED_STATE}:'${keepalived_master}':g' -e 's:${SUB_KEEPALIVED_PRIORITY}:'${keepalived_master_priority}':g' -e 's:${SUB_VIP}:'${vip}':g' > ${tmp_dir}/znvtools/config/keepalived.conf
cp ./scripts/*  ${tmp_dir}/znvtools/scripts/
#replace_param   "./scripts/backup.sh"  "${tmp_dir}/znvtools/scripts/backup.sh"
#replace_param  "./scripts/check_mysql_status.sh"  "${tmp_dir}/znvtools/scripts/check_mysql_status.sh"
#replace_param  "./scripts/check.sh"   "${tmp_dir}/znvtools/scripts/check.sh"
#replace_param  "./scripts/check_trap.sh"  "${tmp_dir}/znvtools/scripts/check_trap.sh"
replace_param  "./scripts/send_mail.pl"  "${tmp_dir}/znvtools/scripts/send_mail.pl"
#replace_param  "./scripts/switch.sh"  "${tmp_dir}/znvtools/scripts/switch.sh"
#replace_param  "./scripts/mysql_oper.sh"  "${tmp_dir}/znvtools/scripts/mysql_oper.sh"
replace_param  "./scripts/keepalived.service" "${tmp_dir}/znvtools/scripts/keepalived.service"
replace_param  "./scripts/mysql.service" "${tmp_dir}/znvtools/scripts/mysql.service"
#replace_param  "./scripts/mysql.server.fake" "${tmp_dir}/znvtools/scripts/mysql.server.fake"

#cp  ./scripts/automatic_backup.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/get_ip.pl  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/notify_backup.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/notify_master.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/start.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/stop.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/tools.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/writelog.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/check_mysql_status_with_log.sh  ${tmp_dir}/znvtools/scripts/
#cp  ./scripts/send_mail.sh  ${tmp_dir}/znvtools/scripts/

cat > "${tmp_dir}/znvtools/scripts/config.param" <<EOF
mysql_software_base=${mysql_software_prefix}/${mysql_software_version}
mysql_path=
mysqld_safe=
db_dir=${mysql_data_path}
backup_base_dir=${backup_base}
expire_days=30
EOF

cp -a ${tmp_dir}/znvtools "${mysql_data_path}/"
cp -a ${tmp_dir}/znvtools ${tmp_dir}/znvtools_for_slave
cat ./config/keepalived.conf |sed -e 's:${SUB_KEEPALIVED_BASE}:'"$mysql_data_path"':g' -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_KEEPALIVED_STATE}:'${keepalived_backup}':g' -e 's:${SUB_KEEPALIVED_PRIORITY}:'${keepalived_backup_priority}':g'  -e 's:${SUB_VIP}:'${vip}':g' > ${tmp_dir}/znvtools_for_slave/config/keepalived.conf

chown -R ${os_user_mysql}:${os_user_mysql_group} "${mysql_data_path}"
chown -R root:root "${mysql_data_path}/znvtools/scripts"
chown -R root:root "${mysql_data_path}/znvtools/config"
chmod -R 755 "${mysql_data_path}/znvtools/scripts"


cat my.cnf.template |sed -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_SERVER_ID}:'${master_server_id}':g' -e 's:${SUB_READ_ONLY}:'${master_read_only}':g'   -e 's:${SUB_EVENT_SCHEDULER}:'${master_event_scheduler}':g' >  ${mysql_data_path}/my.cnf



cat my.cnf.template |sed -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_SERVER_ID}:'${slave_server_id}':g' -e 's:${SUB_READ_ONLY}:'${master_read_only}':g'   -e 's:${SUB_EVENT_SCHEDULER}:'${slave_event_scheduler}':g' >  ${tmp_dir}/znvtools_for_slave/my.cnf

cat my.cnf.template |sed -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_SERVER_ID}:'${slave_server_id}':g' -e 's:${SUB_READ_ONLY}:'${slave_read_only}':g'   -e 's:${SUB_EVENT_SCHEDULER}:'${slave_event_scheduler}':g' >  ${tmp_dir}/znvtools_for_slave/my.cnf.slave

cd ${tmp_dir}
tar -czpvf znvtools_for_slave.tar.gz  znvtools_for_slave > /dev/null 2>&1
cd ${cpwd}
mkdir -p ${tmp_dir}/for_slave
mv ${tmp_dir}/znvtools_for_slave.tar.gz ${tmp_dir}/for_slave/
cp "${cpwd}/${mysql_software_version}${file_suffix}"  ${tmp_dir}/for_slave/
cp "${cpwd}/${znvdata_version}${file_suffix}"  ${tmp_dir}/for_slave/
cp "${cpwd}/${backup_software_gzpath}"  ${tmp_dir}/for_slave/

echo "starting mysql database  !"
rm -f ${mysql_data_path}/data/auto.cnf
rm -f ${mysql_data_path}/log/binlog*
${mysql_software_prefix}/${mysql_software_version}/bin/mysqld_safe --defaults-file=${mysql_data_path}/my.cnf &
sleep 5
check_mysql_until_timeout  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql"  "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "60"
[ $? -eq 1 ] && echo "mysql start failed ,install exit !" && exit 1

if [  ${conn_userpwd} ] ; then
use_pwd=" -p${conn_userpwd}"
fi;

echo "configure mysql database files !"
${mysql_software_prefix}/${mysql_software_version}/bin/mysql  -u${conn_username}  ${use_pwd} --socket=${mysql_data_path}/var/${mysql_port}.socket -e "reset master ; reset slave all;"  

#create ops user
v_sql="create user IF NOT EXISTS ${ops_username}@\"%\" identified by \"${ops_password}\";alter user  ${ops_username}@\"%\" identified by \"${ops_password}\";grant all on *.* to ${ops_username}@\"%\" with grant option;flush privileges;"
create_opsuser "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" ${conn_username}  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${msg_create_opsuer_success}"  "${msg_create_opsuer_fail}" "${msg_create_opsuer_tip}" "${v_sql}" "${ops_username}"  "${ops_password}"  

#create repl user
v_sql="create user IF NOT EXISTS ${repl_username}@\"%\" identified by \"${repl_userpwd}\";alter user  ${repl_username}@\"%\" identified by \"${repl_userpwd}\";grant replication client,replication slave on *.*  to ${repl_username}@\"%\";flush privileges;"
create_opsuser "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" ${conn_username}  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${msg_create_repl_success}"  "${msg_create_repl_fail}" "${msg_create_repl_tip}" "${v_sql}"  "${repl_username}"  "${repl_userpwd}" "${master_hostip}" "${mysql_port}"

#create applicate user
if [ ${application_userpasswd} ] ; then
v_sql="create user IF NOT EXISTS ${application_username}@\"%\" identified by \"${application_userpasswd}\";alter user  ${application_username}@\"%\" identified by \"${application_userpasswd}\";flush privileges;"
create_opsuser "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" ${conn_username}  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${msg_create_app_user_success}"  "${msg_create_app_user_fail}" "${msg_create_app_user_tip}" "${v_sql}"  "${application_username}"  "${application_userpasswd}"  "${master_hostip}" "${mysql_port}"
#for db in dcvs  dcvs_auth  dcvs_apinetwork  metadata_schema dcvs_schedule  nacos
#do
#v_sql="grant create view,Select,Delete,Insert,Lock tables,References,Execute,Trigger,Update,Usage on ${db}.* to ${application_username};flush privileges;"
#execute_sql "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"   "${conn_userpwd}"  "${v_sql}"
#done
# grant privileges
execute_sql "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"   "${conn_userpwd}" "show databases;"  |grep -v -i '+'|while
read db_name
do
  if [  `check_between  ${db_name}  "performance_schema"  "information_schema"  "mysql"  "sys" ` -eq 1 ] ; then
       v_sql="grant create view,Select,Delete,Insert,Lock tables,References,Execute,Trigger,Update,Usage on ${db_name}.* to ${application_username};flush privileges;"
  else
       v_sql="grant Select,Usage on ${db_name}.* to ${application_username};flush privileges;"
  fi
  execute_sql "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"   "${conn_userpwd}"  "${v_sql}"
done

for db in data_collection
do
v_sql="grant all on ${db}.* to ${application_username};flush privileges;"
execute_sql "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"   "${conn_userpwd}"  "${v_sql}"
done

fi;


mysql_login_path_manual_config_tip="please configue later manually with login-path= ${mysql_port} user=${ops_username} and socket=${mysql_data_path}/var/${mysql_port}.socket and password=${ops_password} "

#configure login path
#1 mysql_bin_path
#2 user
#3 socket
#4 pwd
#5 port
#6 tips
#7 success
#8 fail
#9 exists
configure_login_path_until_timeout "300" "${mysql_software_prefix}/${mysql_software_version}"  "${ops_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${ops_password}" "${mysql_port}"  "${msg_login_path_tip}" "${msg_login_path_ok}"  "${msg_login_path_fail}" "${msg_login_path_exists}" "${mysql_login_path_manual_config_tip}"
#configure auto backup
#1 cron_expression
#2 script
#3 tips
#4 success
#5 has_exists
#6 fail
#7 logfile
configure_cron  "${cron_expression_backup}"  "${mysql_data_path}/znvtools/scripts/automatic_backup.sh  ${mysql_port}"  "${msg_auto_backup_tip}"  "${msg_auto_backup_ok}"  "${msg_auto_backup_exists}"  "${msg_auto_backup_fail}" "${mysql_data_path}/znvtools/log/run.log"

echo "configure project file "
mk_project_file "${project_name}"  "${mysql_software_prefix}/${mysql_software_version}" "${mysql_data_path}" 

shutdown_mysql "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"   "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${mysql_port}"

echo "config mysql service "
config_mysql_service
check_mysql_until_timeout  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql"  "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "60"


echo "install backup software "
[ -e "${backup_software_gzpath}" ] && tar -xzpvf ${backup_software_gzpath} > /dev/null
[ -d "${backup_software_gzpath%%.*}" ] && rpm -ivUh "${backup_software_gzpath%%.*}/*"

if [ ${running_mode} == ${running_mode_master_slave} ] ; then
#configure replication check
configure_cron  "${cron_expression_replication_check}"  "${mysql_data_path}/znvtools/scripts/check_mysql_status_with_log.sh ${mysql_port}"  "${msg_replication_check_tip}"  "${msg_replication_check_ok}"  "${msg_replication_check_exists}"  "${msg_replication_check_fail}" "${mysql_data_path}/znvtools/log/run.log"


echo "configure master replicateion from  first slave ";
${mysql_software_prefix}/${mysql_software_version}/bin/mysql  -u${conn_username}  ${use_pwd}  --socket=${mysql_data_path}/var/${mysql_port}.socket <<eof
change master to master_host="${slave_hostip}", master_port=${mysql_port} ,master_user="${repl_username}",master_password="${repl_userpwd}" ;
start slave;
eof
sleep 2

sed -r -i -e "s%"'^\s*(read_only)\s*=\s*(([oO][fF]{2})|0)\s*$'"%\1=ON%" -e "s%"'^\s*(super_read_only)\s*=\s*(([oO][fF]{2})|0)\s*$'"%\1=ON%"  -e "s%"'^\s*(event_scheduler)\s*=\s*(([oO][nN])|1)\s*$'"%\1=OFF%" "${mysql_data_path}/my.cnf"

echo "configu keepalived service"
config_keepalived_service

echo "transport install file to slave host and start mysql  after install has complete !"

echo '
#! /bin/bash
#functions
get_param_value(){
#$1 param_name
#$2 cofig_file_name
local param_row
echo `grep -o -E ^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[0-9.a-zA-Z_/-]+[[:blank:]]*  $2|cut -d '=' -f 2`
}

get_param_value_with_default(){
#$1 param_name
#$2 cofig_file_name
#$3 defalut value
local pvalue=`get_param_value $1 $2`
pvalue=${pvalue:=$3}
echo ${pvalue}
}

replace_param(){
#3 org_file
#4 tar_file
cat $1 |sed -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_BACKUP_BASE}:'${backup_base}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_KEEPALIVED_BASE}:'"$mysql_data_path/../"':g' -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_PROJECT_NAME}:'${project_name}':g'  -e 's:${SUB_VIP}:'${vip}':g' > $2
}

check_mysql(){
#1 mysqlpath
#2 conn_user
#3 socket
#4 usepwd
local flag
local mysql=$1
local user=$2
local socket=$3
local usepwd=` [ $4 ] && echo "-p$4" ` 
flag=`${mysql} -u${user} ${usepwd}  --socket=${socket} -e " select 1 flag;"|grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo 0
else
        echo 1
fi;
}

check_mysql_until_timeout(){
#1 mysqlpath
#2 conn_user
#3 socket
#4 usepwd
#5 times
local waittime=0
local timeout=$5
while (( "${waittime} < ${timeout}" ))
do
echo "check loop count:$[waittime/5]"
[ `check_mysql "$1"  "$2"  "$3"  "$4"` -eq 0 ] && return 0 
sleep 5
let "waittime+=5"
done
return 1
}

create_opsuser(){
#1 mysqlpath
#2 conn_user
#3 socket
#4 usepwd
#5 success
#6 fail
#7 tips
#8 sql_scripts
#9 c_username
#10 c_userpwd
#11 hostip
#12 port
local mysql=$1
local user=$2
local socket=$3
local usepwd=` [ $4 ] && echo "-p$4" ` 
local flag=
echo $7
${mysql} -u${user} ${usepwd}  --socket=${socket} <<!
${8}
!
if [  "${11}" ] ; then 
flag=`${mysql} -u${9} -p${10}  --host=${11} -P${12} --protocol=tcp -e " select 1 flag;"|grep -v flag `
else
flag=`${mysql} -u${9} -p${10}  --socket=${socket} -e " select 1 flag;"|grep -v flag `
fi;

flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo $5
else
        echo $6
fi;
}

check_mysql_by_loginpath(){
#1 mysqlpath
#2 pathName
#3 socket
local mysql=$1
local login_path=$2
local flag=
flag=`$mysql --login-path=${login_path} -u${ops_username} -e " select 1 flag;"|grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo 0
else
        echo 1
fi;
}

check_between(){
local i=1
first_param=
[ ! $1 ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return;
let "i+=1"
done
echo 1
}

configure_login_path(){
#1 mysql_bin_path
#2 user
#3 socket
#4 pwd
#5 port
#6 tips
#7 success
#8 fail
#9 exists
local mysql_bin_path=$1
local user=$2
local socket=$3
local pwd=$4
local port=$5
local choice=
echo $6
if [ `"${mysql_bin_path}/bin/mysql_config_editor" print -G${port}|wc -l` -gt 1 ] ;then 
	echo $9
#	echo "please make a choice ,[S]kip or [R]pace ?"
#	read choice
#	if [ `check_between  ${choice} "S" ` -eq 0  ] ; then 
#		echo "skip configure login path"
#	    return;
#	else 
		echo "replace login path"
		"${mysql_bin_path}/bin/mysql_config_editor" remove -G${port}
#	fi;
fi;
}

#0 2 * * * sh /data/keepalived/scripts/automatic_backup.sh  >> /data/keepalived/log/run.log 2>&1
#*/10 * * * * sh /data/keepalived/scripts/check_mysql_status_with_log.sh  >> /data/keepalived/log/run.log 2>&1
configure_cron(){
#1 cron_expression
#2 script
#3 tips
#4 success
#5 has_exists
#6 fail
#7 logfile
echo $3
[ `grep "${2}" /var/spool/cron/${os_user}|wc -l` -eq 1 ] && echo $5 && return
echo "$1 sh ${2} >> ${7} 2>&1 " >> /var/spool/cron/${os_user} 
[ $? -eq 0  ] && echo $4 && return
echo $6
}

check_mysql_process(){
#1 port
[ `ps -ef|grep -w  mysqld|grep ${1}|wc -l` -eq 0 ] && echo 0 && return 
echo 1
}

check_mysql_down_untiltimeout(){
#1 port
#2 times
local waittime=0
local timeout=$2
while (( "${waittime} < ${timeout}" ))
do
echo "check loop count:$[waittime/5]"
[ `check_mysql_process "$1"` -eq 0 ] && return 0 
sleep 5
let "waittime+=5"
done
return 1
}


config_os_user(){
#1 os_user_name
#return user_group
local os_user=$1
#local user_mysql_exist=`grep -E "^${os_user}:"  /etc/passwd|wc -l`
#local os_group_mysql_id=`grep -E "^${os_user}:"  /etc/passwd|cut -d ':' -f 4`
#local os_group_mysql=`grep -E "^[A-Za-z0-9]*:[A-Za-z0-9]*:${os_group_mysql_id}:" /etc/group|cut -d ':' -f 1`
local user_exist=`id -un ${os_user}`
local user_group=`id -ng ${os_user}`
[ "${user_mysql_exist}x" == "${os_user}x" ] && echo "${user_group}" && return 0
mkdir -p "/home/${os_user}"
useradd -d "/home/${os_user}" -U  -s "/bin/bash"  -p "${os_user}" "${os_user}"
chown "${os_user}":"${os_user}" "/home/${os_user}"
echo "${os_user}" && return 0
}


mk_project_file(){
#1  projectName
#2  mysqlSoftwarePath
#3  mysqlDataPath
local projectname=$1
local mysqlsoftwarepath=$2
local mysqldatapath=$3
[ ! -d "${projectFilePath}" ] && mkdir "${projectFilePath}"
[ -f "${projectFilePath}/${projectname}.mysql" ] && mv "${projectFilePath}/${projectname}.mysql"  "${projectFilePath}/${projectname}.mysql.${cur_time}"
echo "projectName=${projectname};mysqlSoftwarePath=${mysqlsoftwarepath};mysqlDataPath=${mysqldatapath}; "> "${projectFilePath}/${projectname}.mysql" 
echo $? 
}



check_mysql_by_loginpath(){
#1 mysqlpath
#2 pathName
#3 socket
local mysql=$1
local login_path=$2
local flag=
flag=`$mysql --login-path=${login_path} -u${ops_username} -e " select 1 flag;"|grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo 0
else
        echo 1
fi;
}

check_loginpath_untiltimeout(){
#1 mysqlpath
#2 pathName
#3 timeout
local timeout=$3
local waittime=0
while (( "${waittime} < ${timeout}" ))
do
echo "login path had not configured properly , please do it . check loop count:$[waittime/5]"
[ `check_mysql_by_loginpath "$1" "$2" ` -eq 0 ] && return 0
sleep 5
let "waittime+=5"
done
return 1
}




config_mysql_service(){
systemctl disable mysql_${mysql_port}.service > /dev/null 2>&1
cp -f ${mysql_data_path}/znvtools/scripts/mysql.service  /usr/lib/systemd/system/mysql_${mysql_port}.service
systemctl enable mysql_${mysql_port}.service
systemctl start mysql_${mysql_port}.service
}

config_keepalived_service(){
systemctl disable keepalived_${mysql_port}.service > /dev/null 2>&1
cp -f ${mysql_data_path}/znvtools/scripts/keepalived.service  /usr/lib/systemd/system/keepalived_${mysql_port}.service
systemctl enable keepalived_${mysql_port}.service
systemctl start keepalived_${mysql_port}.service
}

shutdown_mysql(){
local mysql=$1
local user=$2
local socket=$3
local usepwd=` [ $4 ] && echo "-p$4" `
local port=$5
local timeout=30
${mysql} -u${user} ${usepwd}  --socket=${socket} <<!
shutdown;
!
check_mysql_down_untiltimeout  "${port}" "${timeout}"
}


has_slave_host(){
local mysql=$1
local loginpath=$2
local flag=1
[ `$mysql --login-path=${loginpath} -u${ops_username}  -e "show slave hosts  \G " |grep "Server_id"|sed "s/ \{1,\}//g"|cut -d ":" -f 2 ` ] && flag=0
echo $flag
}



common_waittimeout(){
#1 timeout
#2 other
local waittime=0
local timeout=$1
shift
while (( "${waittime} < ${timeout}" ))
do
echo "check loop count:$[waittime/5]"
[ `$@` -eq 0 ] && return 0 
sleep 5
let "waittime+=5"
done
return 1
}

waittimeout_until_has_slave_host(){
#1 timeout
#2 mysqlbinpath
#3 login-path
common_waittimeout "$1" "has_slave_host" "$2" "$3"
}


' > ${cpwd}/execute_for_slave.sh

cat >>${cpwd}/execute_for_slave.sh  <<foe
cur_time=${cur_time}
mysql_port=${mysql_port}
skip_mysql_software=${skip_mysql_software}
os_user=${os_user}
os_user_mysql=${os_user_mysql}
project_name=${project_name}
projectFilePath=${projectFilePath}
mysql_data_path=${mysql_data_path}
mysql_software_prefix=${mysql_software_prefix}
mysql_software_version=${mysql_software_version}

ops_username="autoOPS"
ops_password="b8Ax@^.,0"

mkdir -p ${mysql_software_prefix}   ${mysql_data_path%[/]*}  ${backup_base}  ;
if [ ! `echo "${skip_mysql_software}X" |tr a-z A-Z`  == "SX"  -o  
! -d "${mysql_software_prefix}/${mysql_software_version}" ] ; then 
tar -xzpvf /tmp/${mysql_software_version}${file_suffix} -C ${mysql_software_prefix}  ;
fi;
tar -xzpvf /tmp/${znvdata_version}${file_suffix} -C ${mysql_data_path%[/]*}  ;
tar -xzpvf /tmp/znvtools_for_slave.tar.gz -C ${mysql_data_path}  ;
mv  ${mysql_data_path}/znvtools_for_slave  ${mysql_data_path}/znvtools  ;
cp  ${mysql_data_path}/znvtools/my.cnf  ${mysql_data_path}/  ;

rm -f ${mysql_data_path}/data/auto.cnf  ;
rm -f ${mysql_data_path}/log/binlog*  ;
echo "starting slave mysql database  "
${mysql_software_prefix}/${mysql_software_version}/bin/mysqld_safe --defaults-file=${mysql_data_path}/my.cnf & 
sleep 5 ;
check_mysql_until_timeout  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql"  "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "60"
foe
echo '
[ $? -eq 1 ] && echo "Attention: slave mysqld start failed ,please check later " 
' >> ${cpwd}/execute_for_slave.sh

cat >>${cpwd}/execute_for_slave.sh  <<foe
#create ops user
#v_sql="create user IF NOT EXISTS ${ops_username}@\"localhost\" identified by \"${ops_password}\";alter user  ${ops_username}@\"localhost\" identified by \"${ops_password}\";grant all on *.* to ${ops_username}@\"localhost\";flush privileges;"
#create_opsuser "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${msg_create_opsuer_success}"  "${msg_create_opsuer_fail}" "${msg_create_opsuer_tip}"  "${v_sql}" "${ops_username}"  "${ops_password}";

echo "reset log  ";
${mysql_software_prefix}/${mysql_software_version}/bin/mysql  -u${conn_username}  ${use_pwd} --socket=${mysql_data_path}/var/${mysql_port}.socket -e "reset master ; reset slave all;" ;
echo "configure slave replicateion from  master ";
${mysql_software_prefix}/${mysql_software_version}/bin/mysql  -u${conn_username}  ${use_pwd}  --socket=${mysql_data_path}/var/${mysql_port}.socket <<eof
change master to master_host="${master_hostip}", master_port=${mysql_port} ,master_user="${repl_username}",master_password="${repl_userpwd}" ;
shutdown;
eof

check_mysql_down_untiltimeout "${mysql_port}" "60"

echo "restart slave database  ";
 
mv  ${mysql_data_path}/znvtools/my.cnf.slave  ${mysql_data_path}/my.cnf  ;


${mysql_software_prefix}/${mysql_software_version}/bin/mysqld_safe --defaults-file=${mysql_data_path}/my.cnf & 
sleep 5 ;
check_mysql_until_timeout  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql"  "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "60"
foe
echo '
[ $? -eq 1 ] && echo "Attention: slave mysqld start failed ,please check later "
' >>${cpwd}/execute_for_slave.sh

cat >>${cpwd}/execute_for_slave.sh  <<foe
echo "start slave threads  ";
${mysql_software_prefix}/${mysql_software_version}/bin/mysql  -u${conn_username}  ${use_pwd}  --socket=${mysql_data_path}/var/${mysql_port}.socket <<eof
start slave;
eof




msg_login_path_fail="configure login path failed.please configue later manually with login-path= ${mysql_port} and socket=${mysql_data_path}/var/${mysql_port}.socket and password=${ops_password} " ;

#configure login path
#1 mysql_bin_path
#2 user
#3 socket
#4 pwd
#5 port
#6 tips
#7 success
#8 fail
#9 exists
#configure_login_path "${mysql_software_prefix}/${mysql_software_version}"  "${ops_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${ops_password}" "${mysql_port}"  "${msg_login_path_tip}" "${msg_login_path_ok}"  "${msg_login_path_fail}" "${msg_login_path_exists}" ;

#configure auto backup
#1 cron_expression
#2 script
#3 tips
#4 success
#5 has_exists
#6 fail
#7 logfile
configure_cron  "${cron_expression_backup}"  "${mysql_data_path}/znvtools/scripts/automatic_backup.sh  ${mysql_port}"  "${msg_auto_backup_tip}"  "${msg_auto_backup_ok}"  "${msg_auto_backup_exists}"  "${msg_auto_backup_fail}" "${mysql_data_path}/znvtools/log/run.log" ;
foe

echo '
os_user_mysql_group_slave=`config_os_user ${os_user_mysql}`
' >>${cpwd}/execute_for_slave.sh

cat >>${cpwd}/execute_for_slave.sh  <<foe
chown -R ${os_user_mysql}:${os_user_mysql_group_slave} ${mysql_data_path}
chown -R root:root  ${mysql_data_path}/znvtools/scripts
chown -R root:root  ${mysql_data_path}/znvtools/config
chmod -R 755 ${mysql_data_path}/znvtools/scripts

#configure replication check
configure_cron  "${cron_expression_replication_check}"  "${mysql_data_path}/znvtools/scripts/check_mysql_status_with_log.sh  ${mysql_port}"  "${msg_replication_check_tip}"  "${msg_replication_check_ok}"  "${msg_replication_check_exists}"  "${msg_replication_check_fail}" "${mysql_data_path}/znvtools/log/run.log" ;


echo "cleaning temp install files  ";
rm -f /tmp/${mysql_software_version}${file_suffix}
rm -f /tmp/${znvdata_version}${file_suffix}
rm -f /tmp/znvtools_for_slave.tar.gz

echo "configure project file "
mk_project_file "${project_name}"  "${mysql_software_prefix}/${mysql_software_version}" "${mysql_data_path}" 

echo "Attention: you should execute the following script using passwd="${ops_password}" on slave host in another terminal window,or this installation may be not work properly!"
echo "${mysql_software_prefix}/${mysql_software_version}/bin/mysql_config_editor  set --login-path=${mysql_port}   --socket=${mysql_data_path}/var/${mysql_port}.socket  --password"

check_loginpath_untiltimeout  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${mysql_port}"  "120"

shutdown_mysql "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"   "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${mysql_port}"
echo "config mysql service "
config_mysql_service
check_mysql_until_timeout  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql"  "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "60"
waittimeout_until_has_slave_host "60"  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${mysql_port}"
config_keepalived_service

echo "install backup software "
cd /tmp
[ -e "${backup_software_gzpath}" ] && tar -xzpvf ${backup_software_gzpath} > /dev/null
[ -d "${backup_software_gzpath%%.*}" ] && rpm -ivUh "${backup_software_gzpath%%.*}/*"

exit 0 ;
foe
mv ${cpwd}/execute_for_slave.sh  ${tmp_dir}/for_slave/
scp ${tmp_dir}/for_slave/*  ${os_user}@${slave_hostip}:/tmp/
echo "install and configure mysql on slave host!"
ssh -t -t ${os_user}@${slave_hostip} bash -i -s <<!
sh  -i  /tmp/execute_for_slave.sh
exit 
!

fi;


echo "database  installed complete ,please check attention and warning!"




