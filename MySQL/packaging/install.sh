#! /bin/bash

cpwd=$(cd `dirname $0`;pwd)
source $cpwd/predefine.sh
cd ${cpwd}
mkdir -p "$mysql_software_prefix"
if [ -d  "${mysql_software_prefix}/${mysql_software_version}"  ] && [ `check_between "${skip_mysql_software}" "R"`  -eq 0 ]; then 
    mv "${mysql_software_prefix}/${mysql_software_version}" "${mysql_software_prefix}/${mysql_software_version}.${cur_time}"
fi
if [  `check_between "${skip_mysql_software}" "S"`  -eq 1 ] || [ ! -d "${mysql_software_prefix}/${mysql_software_version}" ] ; then 
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
cd "${cpwd}/${znv_tools_file}"
mkdir -p ${tmp_dir}/znvtools/config
mkdir -p ${tmp_dir}/znvtools/log
mkdir -p ${tmp_dir}/znvtools/var
mkdir -p ${tmp_dir}/znvtools/scripts
cat ./config/keepalived.conf |sed -e 's:${SUB_KEEPALIVED_BASE}:'"$mysql_data_path"':g' -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_KEEPALIVED_STATE}:'${keepalived_master}':g' -e 's:${SUB_KEEPALIVED_PRIORITY}:'${keepalived_master_priority}':g' -e 's:${SUB_VIP}:'${vip}':g' > ${tmp_dir}/znvtools/config/keepalived.conf

replace_param   "./scripts/backup.sh"  "${tmp_dir}/znvtools/scripts/backup.sh"
replace_param  "./scripts/check_mysql_status.sh"  "${tmp_dir}/znvtools/scripts/check_mysql_status.sh"
replace_param  "./scripts/check.sh"   "${tmp_dir}/znvtools/scripts/check.sh"
replace_param  "./scripts/check_trap.sh"  "${tmp_dir}/znvtools/scripts/check_trap.sh"
replace_param  "./scripts/send_mail.pl"  "${tmp_dir}/znvtools/scripts/send_mail.pl"
replace_param  "./scripts/switch.sh"  "${tmp_dir}/znvtools/scripts/switch.sh"
replace_param  "./scripts/mysql_oper.sh"  "${tmp_dir}/znvtools/scripts/mysql_oper.sh"
replace_param  "./scripts/keepalived.service" "${tmp_dir}/znvtools/scripts/keepalived.service"
replace_param  "./scripts/mysql.service" "${tmp_dir}/znvtools/scripts/mysql.service"
replace_param  "./scripts/mysql.server.fake" "${tmp_dir}/znvtools/scripts/mysql.server.fake"
replace_infile "${cpwd}/start.sh"
replace_infile "${cpwd}/stop.sh"
replace_infile "${cpwd}/uninstall.sh"


cp  ./scripts/automatic_backup.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/get_ip.pl  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/notify_backup.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/notify_master.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/start.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/stop.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/tools.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/writelog.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/check_mysql_status_with_log.sh  ${tmp_dir}/znvtools/scripts/
cp  ./scripts/send_mail.sh  ${tmp_dir}/znvtools/scripts/

cp -a ${tmp_dir}/znvtools "${mysql_data_path}/"

chown -R ${os_user_mysql}:${os_user_mysql_group} "${mysql_data_path}"
chown -R root:root "${mysql_data_path}/znvtools/scripts"
chown -R root:root "${mysql_data_path}/znvtools/config"
chmod -R 755 "${mysql_data_path}/znvtools/scripts"



cat my.cnf.template |sed -e 's:${SUB_PORT}:'${mysql_port}':g' -e 's:${SUB_MYSQL_BASE}:'${mysql_software_prefix}/${mysql_software_version}':g' -e 's:${SUB_PREFIX_DATA_PATH}:'${mysql_data_path}':g' -e 's:${SUB_SERVER_ID}:'${master_server_id}':g' -e 's:${SUB_READ_ONLY}:'${master_read_only}':g'   -e 's:${SUB_EVENT_SCHEDULER}:'${master_event_scheduler}':g' >  ${mysql_data_path}/my.cnf


cd ${cpwd}

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
v_sql="create user IF NOT EXISTS ${ops_username}@\"%\" identified by \"${ops_password}\";alter user  ${ops_username}@\"%\" identified by \"${ops_password}\";grant all on *.* to ${ops_username}@\"%\";flush privileges;"
create_opsuser "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" ${conn_username}  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${msg_create_opsuer_success}"  "${msg_create_opsuer_fail}" "${msg_create_opsuer_tip}" "${v_sql}" "${ops_username}"  "${ops_password}"  

#create repl user
#v_sql="create user IF NOT EXISTS ${repl_username}@\"%\" identified by \"${repl_userpwd}\";alter user  ${repl_username}@\"%\" identified by \"${repl_userpwd}\";grant replication client,replication slave on *.*  to ${repl_username}@\"%\";flush privileges;"
#create_opsuser "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" ${conn_username}  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${msg_create_repl_success}"  "${msg_create_repl_fail}" "${msg_create_repl_tip}" "${v_sql}"  "${repl_username}"  "${repl_userpwd}" "${master_hostip}" "${mysql_port}"

#create applicate user
if [ ${application_userpasswd} ] ; then
v_sql="create user IF NOT EXISTS ${application_username}@\"%\" identified by \"${application_userpasswd}\";alter user  ${application_username}@\"%\" identified by \"${application_userpasswd}\";flush privileges;"
create_opsuser "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" ${conn_username}  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${msg_create_app_user_success}"  "${msg_create_app_user_fail}" "${msg_create_app_user_tip}" "${v_sql}"  "${application_username}"  "${application_userpasswd}"


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



echo "configure project file "
mk_project_file "${project_name}"  "${mysql_software_prefix}/${mysql_software_version}" "${mysql_data_path}" 

shutdown_mysql "${mysql_software_prefix}/${mysql_software_version}/bin/mysql" "${conn_username}"   "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "${mysql_port}"

echo "config mysql service "
config_mysql_service

check_mysql_until_timeout  "${mysql_software_prefix}/${mysql_software_version}/bin/mysql"  "${conn_username}"  "${mysql_data_path}/var/${mysql_port}.socket"  "${conn_userpwd}"  "60"

exit $?
