#! /bin/bash

cur_dir=$(cd `dirname $0`;pwd)
source ${cur_dir}/set_param.sh 
port=$1

if [  "${db_dir}X" == "X"  -o "${mysql}X" == "X"  -o "${ops_username}X" == "X" -o "${port}X" == "X" ] ; then 
	${cur_dir}/send_mail.sh "warning" "SEND_MSG"  "${port}" "Automatic backup failed,Manual intervention is needed! "
	exit 1
fi;

if [ "${expire_days}X" == "X" ] ; then 
	expire_days=30
fi
if [ ${expire_days} -lt 15 ] ; then 
	expire_days=15
fi

#mysql=${SUB_MYSQL_BASE}/bin/mysql
read_only_off='OFF'
read_only_on='ON'
cur_day=`date +%Y-%m-%d`
backup_base_dir=${backup_base_dir}/backup/my${port}
binlog_backup_base_dir=${backup_base_dir}/binlog
xtrabackup=/usr/bin/xtrabackup
#db_dir=${SUB_PREFIX_DATA_PATH}
my_config=${db_dir}/my.cnf
digit=
last_sunday=
binlog_index=
statement_flush="flush binary logs;"
#ops_username="autoOPS"

is_readonly(){
local flag=1
local read_only=`$mysql --login-path=${port} -u${ops_username} -e "show variables like 'read_only' \G " |grep 'Value'|sed 's/ \{1,\}//g'|cut -d ":" -f 2 `
[ ${read_only}x = "${1}x"  ] && flag=0
echo $flag
}

is_slave(){
[ `is_readonly $read_only_on` -eq 0 ] && echo 0
}

is_master(){
[ `is_readonly $read_only_off` -eq 0 ] && echo 0
}

has_slave_host(){
local flag=1
[ `$mysql --login-path=${port} -u${ops_username} -e "show slave hosts  \G " |grep 'Server_id'|sed 's/ \{1,\}//g'|cut -d ":" -f 2 ` ] && flag=0
echo $flag
}

can_backup(){
( [ `is_master` ] && [ `has_slave_host` -eq 1 ] || [ `is_slave` ] ) && echo 0 
}

is_sunday(){
[ `date +%w` -eq 0 ] && echo 0
}

get_last_sunday(){
local dig;
dig=`date +%w`
echo `date -d "-${dig}  day" +%Y-%m-%d`
}

is_backup_ok(){
#$1 is full_backup_dir
local flag=0;
[ -s "$1/backup.log" ] && flag=`tail -1 "$1/backup.log" |grep 'completed OK'|wc -l`
[ $flag -eq "1" ] && echo 0
}

backup_full(){
echo " backup command : $xtrabackup --defaults-file=$my_config --login-path=${port} -u${ops_username} --target-dir=${backup_base_dir}/${cur_day} --slave-info --safe-slave-backup  --backup  --safe-slave-backup-timeout=3000  --compress --compress-threads=4 >> ${backup_base_dir}/${cur_day}/backup.log 2>&1 "  >> "${backup_base_dir}/${cur_day}/record.log"
$xtrabackup --defaults-file=$my_config --login-path=${port} -u${ops_username} --target-dir="${backup_base_dir}/${cur_day}" --slave-info --safe-slave-backup  --backup  --safe-slave-backup-timeout=3000  --compress --compress-threads=4 >> "${backup_base_dir}/${cur_day}/backup.log" 2>&1
}

backup_increment(){
#$1 is full_backup_dir
local incremental_basedir="$1"
echo " backup command : $xtrabackup --defaults-file=$my_config --login-path=${port} -u${ops_username} --target-dir=${backup_base_dir}/${cur_day}  --incremental-basedir=${incremental_basedir} --slave-info --safe-slave-backup  --backup  --safe-slave-backup-timeout=3000  --compress --compress-threads=4 >> ${backup_base_dir}/${cur_day}/backup.log 2>&1 "  >> "${backup_base_dir}/${cur_day}/record.log"
$xtrabackup --defaults-file=$my_config --login-path=${port} -u${ops_username} --target-dir="${backup_base_dir}/${cur_day}" --incremental-basedir="${incremental_basedir}"      --slave-info --safe-slave-backup  --backup  --safe-slave-backup-timeout=3000  --compress --compress-threads=4 >> "${backup_base_dir}/${cur_day}/backup.log" 2>&1
}

remove_expire_backup(){
if [  -d  "${backup_base_dir}" -a "${backup_base_dir}" =~ backup ] ; then 
	v_pwd=`pwd`
	cd "${backup_base_dir}"
	find . -maxdepth 1 -mtime +${expire_days} -regex './[0-9]*-[0-9]*-[0-9]*'  -execdir rm -fr {} \;
	cd "${v_pwd}"
}

query_without_response(){
#1  statement
sql="$1"
$mysql --login-path=${port} -u${ops_username} -e " ${sql} "
}

backup_binlog(){
#1 binlog_file_path
#2 binlog_backup_base
local binlog_file_path="$1"
local binlog_backup_base="$2"
local binlog_file_name="${binlog_file_path##*/}"
local binlog_tmp_suffix=".tmp"
local tar_suffix=".tar.gz"
local tar_tmp_suffix="${tar_suffix}""${binlog_tmp_suffix}"
[ -f "${binlog_backup_base}/${binlog_file_name}${tar_suffix}"  ] && return 0
[ ! ${binlog_file_path} -o ! -f ${binlog_file_path} -o ! ${binlog_backup_base} -o ! -d ${binlog_backup_base} ] && return 1
rm -f   "${binlog_backup_base}/${binlog_file_name}${binlog_tmp_suffix}"   "${binlog_backup_base}/${binlog_file_name}${tar_tmp_suffix}"
if [ ! -f  ${binlog_backup_base}/${binlog_file_name} ] ; then 
cp "${binlog_file_path}"  "${binlog_backup_base}/${binlog_file_name}${binlog_tmp_suffix}"
mv "${binlog_backup_base}/${binlog_file_name}${binlog_tmp_suffix}"  "${binlog_backup_base}/${binlog_file_name}"
fi;
tar -czpvf  "${binlog_backup_base}/${binlog_file_name}${tar_tmp_suffix}"  "${binlog_backup_base}/${binlog_file_name}"
mv "${binlog_backup_base}/${binlog_file_name}${tar_tmp_suffix}"  "${binlog_backup_base}/${binlog_file_name}${tar_suffix}"
rm -f "${binlog_backup_base}/${binlog_file_name}"
return 0
}

[ ! -d "${backup_base_dir}" ] && mkdir -p  "${backup_base_dir}"
remove_expire_backup
if [ ! `can_backup` ] ; then
	echo " we won't backup  on this instance." 
else
	[  -d  "${backup_base_dir}/${cur_day}" ] && mv "${backup_base_dir}/${cur_day}"  "${backup_base_dir}/${cur_day}.bak"
	mkdir -p "${backup_base_dir}/${cur_day}"
	echo " backup start  `date '+%Y-%m-%d %H:%M:%S'` " > "${backup_base_dir}/${cur_day}/record.log"
		if [ `is_sunday` ] ; then
			backup_full
		else
		{
			digit=`date +%u`
			last_sunday=`date -d "-${digit}  day" +%Y-%m-%d`
			if [ -d "${backup_base_dir}/${last_sunday}" ] && [ `is_backup_ok "${backup_base_dir}/${last_sunday}" ` ] ;then
				backup_increment "${backup_base_dir}/${last_sunday}"
			else
			   echo " finding that the last full backup had errors,automatic do  full backup !"  >> "${backup_base_dir}/${cur_day}/record.log"
			   backup_full
			fi;
		}
		fi;

	echo " backup end  `date '+%Y-%m-%d %H:%M:%S'` " >> "${backup_base_dir}/${cur_day}/record.log"

	[ ! `is_backup_ok  "${backup_base_dir}/${cur_day}"`  ] && ${cur_dir}/send_mail.sh "warning" "SEND_MSG"  "${port}" "Automatic backup failed,Manual intervention is needed! "
fi;
if [  `is_master` ] ; then 
echo "backup binlog!"
[ ! -d ${binlog_backup_base_dir} ] && mkdir -p ${binlog_backup_base_dir}
binlog_index=`$mysql --login-path=${port} -u${ops_username} -e "show variables like 'log_bin_index'\G; "|grep 'Value'|sed 's/ \{1,\}//g'|cut -d ":" -f 2`
cp -f "${binlog_index}"  "${binlog_backup_base_dir}/"
binlog_index=${binlog_index##*/}
query_without_response "${statement_flush}"
while read  binlog_file
do
backup_binlog "${binlog_file}" "${binlog_backup_base_dir}"
done < "${binlog_backup_base_dir}/${binlog_index}"
fi;
exit 0;


