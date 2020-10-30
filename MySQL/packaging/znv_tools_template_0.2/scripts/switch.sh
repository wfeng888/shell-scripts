#! /bin/bash
cpwd=$(cd `dirname $0`; pwd)
roleswitchto=$2
to_master='TO_MASTER'
to_backup='TO_BACKUP'
switch_fail_flag='SEND_MSG'
port=$1
mysql=${SUB_MYSQL_BASE}/bin/mysql
db_dir=${SUB_PREFIX_DATA_PATH}
sec_behind=
timeout=600
waittime=0
master_flag='OFF'
slave_flag='ON'
sleeptime=10
slave_not_running="Critical error !the mysql switch failed . the mysql slave thread may be not running! "
strategy_forever=0
stragety_until=1
ops_username="autoOPS"
#strategy 
#0:loop until slave and master has consistence data. 
#1:loop  before slave and master become consistence  until timeout
strategy=$stragety_until
readonly   sleeptime master_flag slave_flag

do_switch_to_master(){
$mysql --login-path=${port} -u${ops_username} <<!
set global read_only=0;
set global super_read_only=0;
set global event_scheduler=on;
!
}

do_switch_to_backup(){
$mysql --login-path=${port} -u${ops_username} <<!
set global read_only=1;
set global super_read_only=1;
set global event_scheduler=off;
start slave;
!
}

do_switch(){
if [ "$roleswitchto" -a "$roleswitchto" == "$to_master"  ] ; then 
	do_switch_to_master;
        echo "switch to master finished successfully ! "
elif [ "$roleswitchto" -a "$roleswitchto" == "$to_backup" ] ; then 
	do_switch_to_backup;
	echo "switch to backup finished successfully ! "
else 
	echo "script: $0 get wrong param . current is ${roleswitchto} , but need ${to_master} or ${to_backup} . or database status is not valid . please check!"
fi;
}


check_role(){
local flag=1
local event_schedual=`$mysql --login-path=${port} -u${ops_username} -e "show variables like 'read_only' \G " |grep  'Value'|sed 's/ \{1,\}//g'|cut -d ":" -f 2 `
[ ${event_schedual}x = "${1}x"  ] && flag=0
echo $flag
}

is_slave(){
[ `check_role $slave_flag` -eq 0 ] && echo 0
}

is_master(){
[ `check_role $master_flag` -eq 0 ] && echo 0 
}




get_lag(){
local flag;
local Master_Log_File=`$mysql --login-path=${port} -u${ops_username} -e "show  slave status \G " |grep -i -E '^[ ]*Master_Log_File:'|cut -d ":" -f 2 `
local Read_Master_Log_Pos=`$mysql --login-path=${port}  -u${ops_username}  -e "show  slave status \G " |grep -i -E '^[ ]*Read_Master_Log_Pos:'|cut -d ":" -f 2 `
local Relay_Master_Log_File=`$mysql --login-path=${port}  -u${ops_username}  -e "show  slave status \G " |grep -i -E '^[ ]*Relay_Master_Log_File:'|cut -d ":" -f 2 `
local Exec_Master_Log_Pos=`$mysql --login-path=${port}  -u${ops_username}  -e "show  slave status \G " |grep -i -E '^[ ]*Exec_Master_Log_Pos:'|cut -d ":" -f 2 `
local l_sql_running=`is_sql_running`
[ ${Master_Log_File}x =  ${Relay_Master_Log_File}x ]  && [ ${Read_Master_Log_Pos}x =  ${Exec_Master_Log_Pos}x ] && [ ${l_sql_running} ] && echo 0 && return
[ ! ${l_sql_running} ] && echo -1 && return
[ ${Master_Log_File}x =  ${Relay_Master_Log_File}x ]  && [ ${l_sql_running} ] && echo 1 && return 
[ ${Master_Log_File}x !=  ${Relay_Master_Log_File}x ]  && [ ${l_sql_running} ] && echo 2 && return 
}

is_sql_running(){
local Slave_SQL_Running=`$mysql --login-path=${port}  -u${ops_username}  -e "show  slave status \G " |grep -i -E '^[ ]*Slave_SQL_Running:'|sed 's/ \{1,\}//g'|cut -d ":" -f 2 `
[ ${Slave_SQL_Running}x = 'Yesx' ] &&echo 0
}

stopping(){
PROLOGUE=$(echo "$(date +"%a %b %e %X %Y")": \[$PPID:$$\])
echo "$PROLOGUE" STOPPING
}

{
trap "stopping; exit 0;"  HUP INT QUIT USR1 USR2 PIPE ALRM

[ "$roleswitchto" = "$to_backup" ]  || ( [ `is_master` ] && [ "$roleswitchto" = "$to_master" ] ) && do_switch && exit 0;

[ $strategy -eq $strategy_forever ] && timeout=99999
ischange=`check_role ${master_flag}`
while (( "${waittime} < ${timeout}" ))
do
[ ${ischange} -ne `check_role ${master_flag}` ] && echo "the mysql has changed his state while another changing process is running before ,terminate unfinished changing ."
sec_behind=`get_lag`
echo " switch loop count:$[waittime/10], sec_behind:${sec_behind}"
if [ ${sec_behind:--1} -eq -1 ] && [ `is_slave` ] && [ "$roleswitchto" = "$to_master" ] ;then
{
echo "${slave_not_running}" ;

echo "wait some time "
#${cpwd}/send_mail.sh "critical error!" "$switch_fail_flag" "${port}"  "${slave_not_running}" ;

#exit 1; 
}
fi;
if [  ${sec_behind:-1} -gt 0 ] ;then
        sleep $sleeptime;
else
        break;
fi;
let "waittime+=10"
done
do_switch;


} >> ${cpwd}/../log/run.log  2>&1
