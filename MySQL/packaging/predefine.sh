#! /bin/bash


#functions


get_env_value(){
#1 param_name
local p_value=
p_value=`eval echo '$'"$1"`
[ ! ${p_value} ] && p_value=$2
echo ${p_value}
[ ${p_value} ] && return 0
return 1
}


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

get_value(){
#1 param_name
#2 config_file_path
#3 default_value
local p_value=
p_value=`get_env_value $1`
if test -z ${p_value} ; then 
    p_value=`get_param_value_with_default $1 $2 $3`
fi
echo ${p_value}
[ ${p_value} ] && return 0
return 1
}

replace_param(){
#3 org_file
#4 tar_file
cat $1 |sed -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_BACKUP_BASE}:'${backup_base}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_KEEPALIVED_BASE}:'"$mysql_data_path/../"':g' -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_PROJECT_NAME}:'${project_name}':g'  -e 's:${SUB_VIP}:'${vip}':g' > $2
}

replace_infile(){
sed -i -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_BACKUP_BASE}:'${backup_base}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_KEEPALIVED_BASE}:'"$mysql_data_path/../"':g' -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_PROJECT_NAME}:'${project_name}':g'  -e 's:${SUB_VIP}:'${vip}':g'  "$1"
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

${mysql} -u${user} ${usepwd}  --socket=${socket} -N -f  <<!
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
[ ! -f  "${projectFilePath}/${projectname}" ] && echo  0 && return 0
echo 1
}

mk_project_file(){
#1  projectName
#2  mysqlSoftwarePath
#3  mysqlDataPath
local l_projectname=$1
local l_mysqlsoftwarepath=$2
local l_mysqldatapath=$3
[ ! -d "${projectFilePath}" ] && mkdir "${projectFilePath}"
[ -f "${projectFilePath}/${l_projectname}" ] && mv "${projectFilePath}/${l_projectname}"  "${projectFilePath}/${l_projectname}.${cur_time}"
echo "${pname_project_name}=${l_projectname};${pname_mysqlSoftwarePath}=${l_mysqlsoftwarepath};${pname_mysqlDataPath}=${l_mysqldatapath};"> "${projectFilePath}/${l_projectname}" 
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



parse_param(){
#1 str
#2 pname
local l_value
l_value=`echo "${1}"|awk -F ';' -v  p_name="${2}=" '{for(i=1;i<=NF;i++){if($i ~ p_name) {print $i;break;}}}'|cut -d '=' -f 2  `
[ ${l_value} ] && echo ${l_value} && return 0
return 1
}


cpwd=$(cd `dirname $0`; pwd)
source ${cpwd}/env.conf
projectFilePath="/etc/znvTab"
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
pname_skip_mysql_software="skip_mysql_software"
pname_mysqlsoftwarepath="mysqlsoftwarepath"
pname_mysqlDataPath="mysqlDataPath"

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

msg_skip_mysql_software="mysql software exists ,skip. "
msg_port_busy="mysql port ${mysql_port} you configured must be busy,deal with this or using another port!"



cron_expression_backup="0 2 * * *"
cron_expression_replication_check="*/10 * * * *"
default_software_prefix="/usr/local/znv"
default_repl_username="znvrepl"
default_repl_userpwd="znvrepl"
default_conn_username="root"
default_conn_userpwd=
default_application_username="dcvsopr"
default_application_userpwd="sI8#,lO."
default_znv_tools_template="znv_tools_template"
ops_username="autoOPS"
ops_password="b8Ax@^.,0"


mysql_port=`get_value ${pname_mysql_port} ${config_file}`
mysql_data_base=`get_value ${pname_mysql_data_path} ${config_file}`
#slave_hostip=`get_param_value ${pname_slave_hostip}  ${config_file} `
#master_hostip=`get_value ${pname_master_hostip} ${config_file}`
#backup_base=`get_param_value ${pname_backup_base}  ${config_file} `
#vip=`get_param_value ${pname_vip}  ${config_file} `
mysql_software_version=`get_value ${pname_mysql_software_version}  ${version_file}`
znvdata_version=`get_value ${pname_znvdata_version} ${version_file}`
project_name=`get_value ${pname_project_name}  ${config_file}`".mysql.${mysql_port}"    
cur_time=`date +%Y-%m-%d-%H-%M-%S`

mysql_software_prefix=`get_value ${pname_mysql_software_prefix} ${version_file} ${default_software_prefix}`
mysql_data_path=`echo "${mysql_data_base}/my${mysql_port}/${znvdata_version}" `
#repl_username=`get_param_value_with_default ${pname_repl_username}  ${config_file} ${default_repl_username}`
#repl_userpwd=`get_param_value_with_default ${pname_repl_userpwd}  ${config_file} ${default_repl_userpwd}`
conn_username=`get_value ${pname_conn_username} ${config_file} ${default_conn_username}`
conn_userpwd=`get_value ${pname_conn_userpwd} ${config_file}`
#running_mode=`get_param_value ${pname_mode}  ${config_file} `
znv_tools_file=`get_value ${pname_znv_tools_file} ${version_file} ${default_znv_tools_template}`
application_username=`get_value ${pname_application_username} ${config_file} ${default_application_username}`
application_userpasswd=`get_value ${pname_application_userpasswd} ${config_file} ${default_application_userpwd}`
skip_mysql_software=`get_value ${pname_skip_mysql_software} ${config_file}`


running_mode_master_slave="MASTER_SLAVE"
running_mode_single="SINGLE"
use_pwd=
keepalived_master="MASTER"
keepalived_backup="BACKUP"
keepalived_master_priority=100
keepalived_backup_priority=90
tmp_dir=${cpwd}/${cur_time}
master_server_id=1
slave_server_id=2
master_read_only=OFF
slave_read_only=ON
master_event_scheduler=1
slave_event_scheduler=0


slave_has_errors=
os_user=`id -un`
command_prefix=
os_user_root="root"
os_user_mysql="mysql"
os_user_mysql_group=

running_mode=$running_mode_single
