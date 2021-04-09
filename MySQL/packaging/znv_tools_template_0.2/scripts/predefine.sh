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

get_command_value(){
#1 value
#2 param_name
#3 config_file_path
#4 default_value
if [ "${1##*( )}X" != "X" ] ; then 
	echo "${var##*( )}"
else
    get_value "$2" "$3"  "$4"
fi
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




update_config_file(){
#1 config_name
#2 config_value
#3 config_file
if [ `grep -E '^\s*'"${1}"'\s*=\s*\S*' $3|wc -l` -gt 0 ]; then 
	sed -r -i 's&(^\s*'"${1}"'\s*)=\s*\S*&\1='"${2}"'&' $3
else
	echo "$1=$2" >> $3
fi
}

remove_config(){
#1 config_name
#2 config_file
if [ `grep -E '^\s*'"${1}"'\s*=\s*\S*' $2|wc -l` -gt 0 ]; then 
    sed -r -i 's&(^\s*'"${1}"'\s*)=&\#\1=&' $2
fi
}


check_between(){
local i=1
first_param=
[ "${1}X" == "X" ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return;
let "i+=1"
done
echo 1
}



replace_infile(){
sed -i -e 's:${SUB_PREFIX_ES_PATH}:'${base_dir}/${package_name}':g' -e 's:${SUB_CLUSTERNAME}:'${cluster_name}':g' "$1"
}

file_is_empty(){
#1 filepath
local num=0
if test -r $1 ; then 
num=`grep -v -E '^#|^\s*$' $1|wc -l `
fi;
[ $num -eq 0 ] && echo 0 && return 0
echo 1 && return 1
}


get_login_cmd(){
local mysql="$1"
local mysql_user="$2"
local mysql_passwd=` [ $3 ] && echo "-p$3" `
local mysql_ip="$4"
local mysql_port="$5"
local socket="$6"
local l_login=
if [ "${socket}X" == "X" ] ; then 
    l_login="${mysql} -u${mysql_user}  ${mysql_passwd} -h${mysql_ip} -P${mysql_port} --protocol=tcp"
else
    l_login="${mysql} -u${mysql_user}  ${mysql_passwd} -S${socket} "
fi;
echo "${l_login}"
}

exec_sql(){
local sql="$1"
local has_semicolon=$(echo "${sql}"|tail -1| sed -e 's/[ ]*$//g')
[  "${has_semicolon: -1}"X != ";X" ] && sql="${sql};"
cat >> "${sqllog}" <<EOF
**********************execute sql **************************************
${sql}
**********************execute log **************************************
EOF
eval "${login}" -f  <<!  >> "${sqllog}" 2>&1
select 'start' ,sysdate() from dual;
${sql}
select 'end' ,sysdate() from dual;
!
}


check_mysql_alive(){
local flag=1
flag=`${login}  -e " select 1 flag;"|grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then
        echo 0
else
        echo 1
fi;
}


check_sql_exec_result(){
	return `grep -w 'ERROR' ${sqllog}|wc -l`
}

cur_time=`date +%Y%m%d%H%M%S`
cur_dir=$(cd `dirname $0`;pwd) 
config_file="${cur_dir}/config.param"
if test -r "${cur_dir}/env.conf" ; then 
source "${cur_dir}/env.conf"
fi