#!/bin/bash

#functions
get_param_value(){
#$1 param_name
#$2 cofig_file_name
local param_row
echo `grep -o -E ^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[0-9.a-zA-Z_/:\|,\*-]+[[:blank:]]*  $2|cut -d '=' -f 2`
}

remove_expire_backup(){
base_dir=$1
expire_d=$2
expr ${expire_d} "+" 10 > /dev/null 2>&1
ret=$?
[ $ret -ne 0  ] && return 1
[ $expire_d  -lt 1 ] && return 1
earliest_day=`date -d "-${expire_d} day" +%Y%m%d`
old_pwd=`pwd`
cd ${base_dir}
ls -1|grep -E '^[1-9][0-9]{7}$'|awk -v ed=${earliest_day} '{if( $1 < ed ) { print $1} }'|xargs rm -fr 
cd ${old_pwd}
}

exec_sql(){
local sql="$1"
local mysql="$2"
local login_path="$3"
local has_semicolon=$(echo "${sql}"|tail -1| sed -e 's/[ ]*$//g')
[  "${has_semicolon: -1}"X != ";X" ] && sql="${sql};"
${mysql} --login-path="${login_path}"  -N -e "${sql}"
}


config_file="$1"
cur_time=`date +%Y%m%d%H%M%S`
backup_base_dir=`get_param_value  "backup_base_dir"  $1`
[ ! -d "${backup_base_dir}" ] && mkdir -p  "${backup_base_dir}"
{
cur_day=`date +%Y%m%d`
backup_dir=
backup_sql=

backup_data=`get_param_value  "backup_data"  $1`
mysqldump_path=`get_param_value  "mysqldump_path"  $1`
mysql=${mysqldump_path%/*}"/mysql"
login_path=`get_param_value  "login_path"  $1`

expire_days=`get_param_value  "expire_days"  $1`
dump_sql="${mysqldump_path}  --login-path=${login_path}   --allow-keywords --set-gtid-purged=OFF --skip-lock-tables --single-transaction "


[ -d "${backup_base_dir}/${cur_day}" ] && mv "${backup_base_dir}/${cur_day}"  "${backup_base_dir}/${cur_day}.bak${cur_time}"
backup_dir="${backup_base_dir}/${cur_day}"
mkdir -p "${backup_dir}" 
declare $(echo "${backup_data}"| awk  -F ',' 'BEGIN{i=1;k=0;} {for(;i<=NF;i++&&k++){printf("dbs[%d]=%s  ",k,$i)}}')
for (( i=0 ; i<${#dbs[@]} ; i++ )) {
unset db_name exclude_flag table_list backup_sql db_param tab_num j 
db_name=`echo ${dbs[i]}|cut -d ':' -f 1`
exclude_flag=`echo ${dbs[i]}|cut -s -d ':' -f 2|cut -c 1`
ori_table_list=`echo ${dbs[i]}|cut -s -d ':' -f 2`
tab_num=`echo $ori_table_list|awk -F '|' '{print NF}'`
j=1
table_list=
[ "${exclude_flag}X" == "-X" ] && ori_table_list=${ori_table_list#?} && db_param=" -B "
while(( "${j} <= ${tab_num}" ))
do
tab_name=`echo "$ori_table_list"|cut -d '|' -f $j`
if [ "${exclude_flag}X" == "-X" ] ; then 
{
	if [[ "$tab_name" =~ "*"$ ]] ; then
	{
		tab_name=${tab_name%?}
		sql="select group_concat(concat('  --ignore-table=',table_schema,'.',table_name) SEPARATOR ' ') from information_schema.tables where table_schema='"${db_name}"' and table_name like '"${tab_name}"%' group by table_schema"
		table_list="${table_list} "`exec_sql "${sql}" "${mysql}" "${login_path}" `
	}
	else
	{
		table_list="${table_list} --ignore-table=${db_name}.${tab_name} "
	}
	fi;
}
else
{
	if [[ "$tab_name" =~ "*"$ ]];then
	{
		tab_name=${tab_name%?}
		sql="select group_concat(table_name SEPARATOR ' ') from information_schema.tables where table_schema='"${db_name}"' and table_name like '"${tab_name}"%' group by table_schema"
		table_list="${table_list} "`exec_sql "${sql}" "${mysql}" "${login_path}" `
	}
	else
	{
		table_list="${table_list} ${tab_name} "
	}
	fi;
}
fi;
let "j+=1"
done
[ "${table_list}X" == "X" ] && db_param=" -B "
backup_sql="${dump_sql}  -r ${backup_dir}/${i}_${db_name}.sql ${db_param} ${db_name} ${table_list}   "
echo "${backup_sql}"
$backup_sql > ${backup_dir}/${i}_${db_name}.log 2>&1
}
cd ${backup_dir}
if [  `pwd` == "${backup_dir}" ]; then
tar -czpvf ${cur_day}.tar.gz *
ls -1|grep -v "${cur_day}.tar.gz"|xargs rm -fr 
fi
remove_expire_backup "${backup_base_dir}"  ${expire_days}
} > "${backup_base_dir}/exec_log.${cur_time}"