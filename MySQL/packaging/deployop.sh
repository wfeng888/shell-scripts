#!/bin/bash

get_param_value(){
#$1 param_name
#$2 cofig_file_name
local param_row
echo `grep -o -E ^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[0-9,.a-zA-Z_/-]+[[:blank:]]*  $2|cut -d '=' -f 2`
}


check_sys_db(){
#1 db_name
[ ${1} == "information_schema"  -o ${1} == "mysql"  -o ${1} == "performance_schema"  -o ${1} == "sys" -o ${1} == "data_collection" ] && echo  1 && return 
echo  0
}

drop_db(){
#1 db_name
#2 mysql
#3 user
#4 password
#5 port
#6 ip
[ `check_sys_db ${1} ` -eq 1 ] && return  
v_sql="drop database ${1}"
exec_sql "${v_sql}" "$2"  "$3" "$4"  "$5" "$6" 
}

exec_sql(){
local sql=$1
local mysql=$2
local user=$3
local passwd=$4
local port=$5
local ip=$6
local sqllog="${cpwd}/exec-sql-log-${cur_time}.log"
local has_semicolon=$(echo "${sql}"|tail -1| sed -e 's/[ ]*$//g')
[  "${has_semicolon: -1}"X != ";X" ] && sql="${sql};"
cat >> "${sqllog}" <<EOF
**********************execute sql **************************************
${sql}
**********************execute log **************************************
EOF
${mysql} -u${user}  -p${passwd} -P${port} -h${ip} --protocol=tcp  -f  <<!  >> "${sqllog}" 2>&1
select 'start' ,sysdate() from dual;
${sql}
select 'end' ,sysdate() from dual;
!
}


backup(){
local mysqldump=$1
local user=$2
local port=$3
local password=$4
local ip=$5
local backupfile=$6
local restore_mode=$7
local restore_param="-c"
[ `echo ${restore_mode}|tr a-z A-Z` == "REPLACE" ] && restore_param="--replace"
${mysqldump} -u"${user}" -p"${password}" -P${port} -h${ip} --protocol=tcp  --skip-extended-insert  -t -n -r "${backupfile}"  --set-gtid-purged=OFF  ${restore_param}  --databases dcvs dcvs_apinetwork dcvs_auth metadata_schema dcvs_schedule
}


cur_time=`date +%Y-%m-%d-%H-%M-%S`
cpwd=$(cd `dir $0`|pwd)
{
git_url="git@10.45.156.100:DCVS/DCVS-DB.git"
git_project="DCVS-DB"
script_dir=$(cd `dirname $0`; pwd)
config_file="${script_dir}/config.deploy"
p_mysqlbase="mysqlbase"
p_mysql_port="port"
p_mysql_hostip="ip"
p_user="user"
p_passwd="password"
p_restore_mode="restore_mode"
p_skip_restore_table="skip_restore_table"
mysqlbase=`get_param_value ${p_mysqlbase} ${config_file}`
mysql="${mysqlbase}/bin/mysql"
mysqldump="${mysqlbase}/bin/mysqldump"
user=`get_param_value ${p_user} ${config_file}`
password=`get_param_value ${p_passwd} ${config_file}`
mysql_port=`get_param_value ${p_mysql_port} ${config_file}`
ip=`get_param_value ${p_mysql_hostip} ${config_file}`
restore_mode=`get_param_value ${p_restore_mode} ${config_file}`
skip_restore_table=`get_param_value ${p_skip_restore_table} ${config_file}`
skip_restore_table=`echo "${skip_restore_table}"|tr ',' '|'|sed 's/ \{1,\}//g'`
backup "${mysqldump}" "${user}" "${mysql_port}" "${password}"  "${ip}"  "${cur_time}.sql.tmp"  "${restore_mode}"
${mysql} -u${user} -p${password} -P${mysql_port} -h${ip} --protocol=tcp -N -e 'show databases' |grep -v -i '+'|while read db_name
do
drop_db ${db_name}  "${mysql}"  "${user}"  "${password}"  "${mysql_port}"  "${ip}"
done;
#git clone ${git_url}>/dev/null 2>&1
cd "${git_project}"
files[0]=
file_seq=0
find .|grep -E '^./[1-9]'|grep -E '\.[Ss][qQ][lL]$'|sort -V -t '/' -k2 > tmp_sort.lst

while read file_name 
do

num=$file_seq
let "file_seq+=1"
current_seq=$num

files[${current_seq}]=${file_name}
[ ${current_seq} -eq 0 ] && continue 


type_num=2
version=`echo "${file_name}" |cut -d'/' -f 2`
declare $(echo "${version}"| awk  -F '.' 'BEGIN{i=1;k=0;} {for(;i<=NF;i++&&k++){printf("versions[%d]=%s  ",k,$i)}}')
type=`echo "${file_name}" |cut -d'/' -f 4`
sort_n=`echo "${file_name}" |cut -d'/' -f 5|cut -d'_' -f 1`
[ `echo ${type}|tr a-z A-Z` == 'TABLES' ] && type_num=1
[ `echo ${type}|tr a-z A-Z` == 'DML' ] && type_num=3

last_seq=${num}
let "last_seq-=1"
tmp_last_seq=${last_seq}
last_version=
last_type=
last_type_num=
last_sort_n=


tmp_current_seq=$num
while (( ${tmp_current_seq} > 0 ))
do
current_seq=${tmp_current_seq}
last_seq=${tmp_last_seq}
let "tmp_current_seq-=1"
let "tmp_last_seq-=1"

switch_flag=0
version_flag=0

last_version=`echo ${files[${last_seq}]}|cut -d '/' -f 2`
last_type=`echo ${files[${last_seq}]}|cut -d '/' -f 4`
last_sort_n=`echo ${files[${last_seq}]}|cut -d '/' -f 5|cut -d'_' -f 1`
declare $(echo "${last_version}"| awk  -F '.' 'BEGIN{i=1;k=0;} {for(;i<=NF;i++&&k++){printf("last_versions[%d]=%s  ",k,$i)}}')

#for i in ${versions[*]} ; do echo $i ; done

versuib_num=${#versions[@]}

for (( i=0 ; i<${versuib_num} ; i++ )) {
if (( "${versions[i]} < ${last_versions[i]}" )) ;then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1
break;
elif (( "${versions[i]} > ${last_versions[i]}" )) ;then 
version_flag=1
break;
fi;
}

[ ${switch_flag} -eq 1 ] && continue

last_type_num=2
[ `echo ${last_type}|tr a-z A-Z` == 'TABLES' ] && last_type_num=1
[ `echo ${last_type}|tr a-z A-Z` == 'DML' ] && last_type_num=3

if [ ${type_num} -lt ${last_type_num} ] ;then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1;
continue;
fi;

#echo ${sort_n}
#echo ${last_sort_n}
if (( 10#${sort_n} < 10#${last_sort_n} )) ;then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1;
continue;
fi;
[ ${switch_flag} -eq 0 -o ${tmp_last_seq} -lt 0 ] && break 
done 

done < tmp_sort.lst

for(( i=0;i<${#files[@]};i++)) 
do
exec_sql "source ${files[i]}"  "${mysql}"  "${user}"  "${password}"  "${mysql_port}"  "${ip}"
done;


cd ..
if [ "${skip_restore_table}X" == "X" ] ; then 
cp ${cur_time}.sql.tmp  ${cur_time}.sql
else
cat ${cur_time}.sql.tmp|grep -v -i -E "${skip_restore_table}" > ${cur_time}.sql
fi;


exec_sql "source ${cur_time}.sql" "${mysql}" "${user}" "${password}" "${mysql_port}" "${ip}" > ${cur_time}.exec.log 2>&1


}>${cur_time}.log