#!/bin/bash

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

check_sys_db(){
#1 db_name
[ ${1} == "information_schema"  -o ${1} == "mysql"  -o ${1} == "performance_schema"  -o ${1} == "sys" ] && echo  1 && return 
echo  0
}

drop_db(){
#1 db_name
#2 mysql
#3 socket_file
[ `check_sys_db ${1} ` -eq 1 ] && return  
v_sql="drop database ${1}"
exec_sql "${v_sql}" "$2"  "$3" 
}

exec_sql(){
local sql="$1"
local mysql="$2"
local socket_file="$3"
local has_semicolon=$(echo "${sql}"|tail -1| sed -e 's/[ ]*$//g')
[  "${has_semicolon: -1}"X != ";X" ] && sql="${sql};"
cat >> "${sqllog}" <<EOF
**********************execute sql **************************************
${sql}
**********************execute log **************************************
EOF
${mysql} -u${conn_username} -p${conn_userpwd} --socket=${socket_file} -f  <<!  >> "${sqllog}" 2>&1
select 'start' ,sysdate() from dual;
${sql}
select 'end' ,sysdate() from dual;
!
}

check_mysql_alive(){
local mysql="$1"
local socket="$2"
local flag=1
flag=`${mysql} -u${conn_username} -p${conn_userpwd}  --socket=${socket} -e " select 1 flag;"  2>/dev/null |grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo 0
else
        echo 1
fi;
}

start_mysql_service(){
local mysql=$1
local socket=$2
local port=$3
local timeout=30
if [ ${isServiceFlag} ] ; then 
   systemctl start mysql_${port}  2>/dev/null
   common_waittimeout "${timeout}" "check_mysql_alive"  "${mysql}"  "${socket}"
fi
}

start_mysql(){
local mysqld_safe=$1
local mysql_cnf=$2
local mysql=$3
local socket=$4
local port=$5
local timeout=60
[ ${isServiceFlag} ] && start_mysql_service "${mysql}"  "${socket}" ${port}
[ `check_mysql_alive  "${mysql}"  "${socket}" ` -eq 0 ] && return 0

${mysqld_safe} --defaults-file=${mysql_cnf} &
common_waittimeout "${timeout}" "check_mysql_alive"  "${mysql}"  "${socket}"
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

is_service(){
local port=$1
local isServiceFlag=`ps -ef|grep ${port}|grep mysqld_safe|sed -e 's: \{1,\}: :g' -e 's:^ ::g'|cut -d ' ' -f 3`
[ ${isServiceFlag:-0} -ne 1  ] && return 1
[ ! ${isServiceFlag}  ] && isServiceFlag=`systemctl list-units mysql_${port}|wc -l `
[ ${isServiceFlag:-0} -eq 1 ] && return 0
return 1
}

shutdown_mysql_service(){
local port=$1
local timeout=30
if [ ${isServiceFlag} ] ; then 
   systemctl stop mysql_${port}
   check_mysql_down_untiltimeout  "${port}" "${timeout}"
fi
}

shutdown_mysql(){
local mysql=$1
local socket=$2
local port=$3
local timeout=30
[ ${isServiceFlag} ] && shutdown_mysql_service ${port}
[ `check_mysql_process ${port}`  -eq  0 ] && return 0
${mysql} -u${conn_username} -p${conn_userpwd}  --socket=${socket} <<!
shutdown;
!
check_mysql_down_untiltimeout  "${port}" "${timeout}"
}

check_log_error(){
#1 logfile
[ `grep -E 'ERROR [0-9]+ \([0-9a-zA-Z]+\) at line' $1|wc -l ` -gt 0 ] && return 1
return 0
}

compare(){
local v1=$1
local v2=$2
if [[ "$v1" =~ ^rhbb_ ]]; then
v1=`echo ${v1}|cut -c 6-`
fi
if [[ "$v2" =~ ^rhbb_ ]]; then
v2=`echo ${v2}|cut -c 6-`
fi
if (( "$v1 < $v2" )) ;then
echo -1
elif (( "$v1 > $v2" )) ;then
echo 1
else
echo 0
fi
}


s_pv1=$1
s_pv2=$2

find -name "*.log" | xargs rm -f
cur_time=`date +%Y-%m-%d-%H-%M-%S`
package_date=`date +%Y%m%d%H%M%S`
cpwd=$(cd `dirname $0`;pwd)
sqllog="${cpwd}/exec-sql-log-${cur_time}.log"
cd ${cpwd}
{
project_git_name="DCVS-DB"
project_git_url="git@10.45.156.100:DCVS/DCVS-DB.git"
pname_conn_username="conn_username"
pname_conn_userpwd="conn_userpwd"
pname_backup_software_gzpath="backup_software_gzpath"
script_dir=$(cd `dirname $0`; pwd)
package_version_file="${script_dir}/package.version.lst"
package_config_file="${script_dir}/package.config.param"
p_mysql_software_version="mysql_software_version"
p_znv_tools_template="znv_tools_template"
p_mysql_software_package_path="mysql_software_package_path"
p_znvdata_version="znvdata_version"
p_mysql_data_base="mysql_data_base"
p_code_library="code_library"
default_code_library="/root/codelibrary"
default_mysql_data_base="/database/my3000"
mysql_software_package=`get_param_value ${p_mysql_software_package_path} ${package_version_file}`
znvdata_version=`get_param_value ${p_znvdata_version} ${package_version_file}`
mysql_data_base=`get_param_value ${p_mysql_data_base} ${package_version_file}`
mysql_data_base="${mysql_data_base:-${default_mysql_data_base}}"
code_library=`get_param_value ${p_code_library} ${package_version_file}`
code_library="${code_library:-${default_code_library}}"
znvdata_version="${znvdata_version%_*}""_""${package_date}"
conn_username=`get_param_value ${pname_conn_username} ${package_config_file}`
conn_userpwd=`get_param_value ${pname_conn_userpwd} ${package_config_file}`
backup_software_gzpath=`get_param_value ${pname_backup_software_gzpath} ${package_config_file}`
[ ! -f ${mysql_software_package}  ] && echo "mysql software package not exists . program exits ." && exit 1 
mysql_software_version=${mysql_software_package##*/}
mysql_software_version=${mysql_software_version%.tar.gz}
old_pwd="`pwd`"


mysql_base="`grep basedir ${mysql_data_base}/my.cnf|cut -d '=' -f 2`/bin"
mysql="${mysql_base}/mysql"
mysqld_safe="${mysql_base}/mysqld_safe"
mysql_port=`grep port ${mysql_data_base}/my.cnf|cut -d'=' -f 2|head -1`
socket_file="${mysql_data_base}/var/${mysql_port}.socket"
isServiceFlag=
is_service ${mysql_port}
[ $? -eq 0 ] && isServiceFlag=true

[ `check_mysql_process ${mysql_port}` -eq 0 ] && start_mysql "${mysqld_safe}" \
"${mysql_data_base}/my.cnf"  "${mysql}"  "${socket_file}" "${mysql_port}"
[ ! -d ${code_library} ] && mkdir -p ${code_library}
cd ${code_library}
#[  -d "${project_git_name}" ] && rm -fr  "${code_library}/${project_git_name}"
#git clone "${project_git_url}">/dev/null 2>&1
znv_tools_template=`ls -l ${project_git_name}/packaging |grep 'znv_tools_template'|sed 's/ \{1,\}/ /g'|cut -d' ' -f 9`
${mysql} -u${conn_username} -p${conn_userpwd} --socket=${socket_file} -N -e 'show databases' |grep -v -i '+'|while read db_name
do
drop_db ${db_name}  "${mysql}"  "${socket_file}"
done;
cd "${code_library}/${project_git_name}"
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
unset versions
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
unset last_versions
declare $(echo "${last_version}"| awk  -F '.' 'BEGIN{i=1;k=0;} {for(;i<=NF;i++&&k++){printf("last_versions[%d]=%s  ",k,$i)}}')

#for i in ${versions[*]} ; do echo $i ; done

versuib_num=${#versions[@]}
last_versuib_num=${#last_versions[@]}
compare_versuib_num=${versuib_num}
if (( "${last_versuib_num} < ${compare_versuib_num}" )) ; then 
compare_versuib_num=${last_versuib_num}
fi


for (( i=0 ; i<${compare_versuib_num} ; i++ )) {
com_flag=`compare ${versions[i]} ${last_versions[i]}`
if [ $com_flag -lt 0 ] ;then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1
break;
elif [ $com_flag -gt 0 ] ;then 
version_flag=1
break;
fi;
}

if (( "${versuib_num} > ${last_versuib_num}" )) ; then 
	version_flag=1
fi;

[ ${switch_flag} -eq 1 ] && continue
[ ${version_flag} -eq 1 ] && break

if (( "${versuib_num} < ${last_versuib_num}" )) ; then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1
fi
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

if [ ${type_num} -gt ${last_type_num} ] ;then 
    break;
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
exec_sql "source ${files[i]}"  "${mysql}"  "${socket_file}"
done;

#打包的时候，将git提交信息写入
pv0=
pv1=
pv2=
G_MODE_VALUE='VALUE'
G_MODE_GET='GET'
if [  "${s_pv1}X" == "X" ] || [ "${s_pv2}X" == "X" ] ; then
	pv0="${G_MODE_GET}"
    pv1="${code_library}/${project_git_name}"
else
	pv0="${G_MODE_VALUE}"
	pv1="${git_hash}|${git_time}"
fi
pv2="PUSH_GIT.SQL"
sh ${cpwd}/push_git.sh  "${pv0}"  "${pv1}" "${pv2}"
[ $? -eq 0 -a  -r "${pv2}"  -a  -s "${pv2}" ]  && exec_sql "source ${pv2}"  "${mysql}"  "${socket_file}"


exec_sql "set global  innodb_fast_shutdown=0"   "${mysql}"  "${socket_file}"
shutdown_mysql "${mysql}" "${socket_file}"  "${mysql_port}"

check_log_error ${sqllog}
[ $? -ne 0 ]  && echo "Some errors has happend during packaing, abort." && exit 1

cd "${code_library}"
[ `pwd` == ${code_library} ] && rm -fr ${znvdata_version}

mkdir -p ${znvdata_version}
cp -a "${mysql_data_base}/data" ${znvdata_version} > /dev/null 2>&1
cp -a "${mysql_data_base}/log" ${znvdata_version} > /dev/null 2>&1
cat /dev/null > "${znvdata_version}/log/log.err"  > /dev/null 2>&1
cat /dev/null > "${znvdata_version}/log/slow.log"  > /dev/null 2>&1
cp -a "${mysql_data_base}/my.cnf" ${znvdata_version} > /dev/null 2>&1
cp -a "${mysql_data_base}/scripts" ${znvdata_version} > /dev/null 2>&1
cp -a "${mysql_data_base}/var" ${znvdata_version} > /dev/null 2>&1
chown -R mysql:mysql ${znvdata_version} > /dev/null 2>&1
tar -czpvf "${znvdata_version}.tar.gz" ${znvdata_version}  --remove-files > /dev/null 2>&1
echo "${p_mysql_software_version}=${mysql_software_version}" > version.lst
echo "${p_znvdata_version}=${znvdata_version}" >> version.lst
echo "${p_znv_tools_template}=${znv_tools_template}" >> version.lst

[ -e ${backup_software_gzpath} ] && cp ${backup_software_gzpath} ./
#cp ${package_config_file} config.param
cat > config.param <<EOF
mysql_port=
mysql_data_base=/database/mysql
slave_hostip=
master_hostip=
backup_base=/database/mysql
vip=
running_mode=SINGLE
project_name=znv-dcvs
mysql_software_prefix=
application_username=${conn_username}
application_userpasswd=${conn_userpwd}
conn_username=${conn_username}
conn_userpwd=${conn_userpwd}
backup_software_gzpath=${backup_software_gzpath##*/}
EOF
#cp "${code_library}/${project_git_name}/packaging/config.deploy" config.deploy
cp "${code_library}/${project_git_name}/packaging/prepare.sh" prepare.sh
cp "${code_library}/${project_git_name}/packaging/prepareForCI.sh" prepareForCI.sh
cp "${code_library}/${project_git_name}/packaging/deployop.sh" deployop.sh
cp "${code_library}/${project_git_name}/packaging/install.sh"  install.sh
cp "${code_library}/${project_git_name}/packaging/start.sh"  start.sh
cp "${code_library}/${project_git_name}/packaging/stop.sh"  stop.sh
cp "${code_library}/${project_git_name}/packaging/check.sh"  check.sh
cp "${code_library}/${project_git_name}/packaging/uninstall.sh" uninstall.sh
cp "${code_library}/${project_git_name}/packaging/predefine.sh" predefine.sh
cp "${code_library}/${project_git_name}/packaging/param_for_deploy_platform.xlsx"  param_for_deploy_platform.xlsx
cp "${mysql_software_package}" "./"
cp -a "${code_library}/${project_git_name}/packaging/${znv_tools_template}"  "./" > /dev/null 2>&1
tar -czpvf "${znv_tools_template}.tar.gz" "${znv_tools_template}" --remove-files > /dev/null 2>&1
tar -czpvf "DCVSDBMYSQL_${package_date}_MYSQL_DCVS.tar.gz"  prepare.sh  \
prepareForCI.sh deployop.sh version.lst config.param config.deploy "${znv_tools_template}.tar.gz" "${znvdata_version}.tar.gz"  \
 "${mysql_software_version}.tar.gz"  install.sh  start.sh  stop.sh check.sh  uninstall.sh predefine.sh \
 param_for_deploy_platform.xlsx  ${backup_software_gzpath##*/} --remove-files

start_mysql "${mysqld_safe}" \
"${mysql_data_base}/my.cnf"  "${mysql}"  "${socket_file}" "${mysql_port}"

}>${cur_time}.log

exit 0 