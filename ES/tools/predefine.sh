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

check_es_alive(){
local is_alive=`netstat -apn|grep -w ${http_port}|grep -w LISTEN|wc -l`
[ ${is_alive} -eq 1 ] && echo 0 && return 0
echo 1 && return 0
}

check_es_stop(){
local is_alive=`netstat -apn|grep -w ${http_port}|grep -w LISTEN|wc -l`
[ ${is_alive} -eq 0 ] && echo 0 && return 0
echo 1 && return 0
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
[ ! $1 ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return;
let "i+=1"
done
echo 1
}

es_execute(){
#1 http_ip
#2 http_port
#3 action
#4 url
#5 url_params
local result;
local l_r_c;
result=`curl -X ${3} "${1}:${2}/${4}?${5}"`
l_r_c=$?
echo ${result}
return ${l_r_c}
}

parse_index_name(){
#1 index file name or index file path
local l_file_name=${1##*/}
local l_r_c=
l_index_name=`echo ${l_file_name##*#} |cut -d '.' -f 1`
l_r_c=$?
echo ${l_index_name}
return ${l_r_c}
}

parse_action_name(){
#1 index file name or index file path
local l_file_name=${1##*/}
local l_r_c=
l_index_name=`echo $l_file_name|cut -d '#' -f 2`
l_r_c=$?
echo ${l_index_name}
return ${l_r_c}
}

check_project_not_exist(){
#1 project_name
local project_name=$1
[ ! -f  "${projectFilePath}/${project_name}.es" ] && echo  0 && return 0
echo 1
}


append_yml_value(){
#$1 config_name
#$2 config_value
#$3 config_file
local config_file=${es_yml}
[ "$3" ] &&  config_file=$3
if [ `echo "$2" | grep '#' ` ] ; then 
	echo "$1:" >> $config_file
	echo $2 |tr '#' ' '|xargs -n 1|while read i; do echo "  - $i" >> ${config_file} ; done
else
	echo "$1: $2" >> $config_file
fi
}

sudo_execute(){
local mode=$2
local stat=-1
if [ "${mode}X" == 'oX' -o  ${os_user_root} == ${cur_user} ];then
	$1
	local stat=$?
	[ ${os_user_root} == ${cur_user} -o $stat -eq 0 ] && return $stat
fi
sudo $1
return $?
}

su_execute(){
if [ "${2}X" == "forceX"  ] ||  [ ${os_user_es} != ${cur_user} ];then
	su -l ${os_user_es} -c "$1"
else
	$1
fi
return $?
}


check_port_busy(){
#1 port
if [ ${os_user_root} != ${cur_user} ]; then 
	flag=` sudo netstat -apn | grep -w ${1} | grep -w LISTEN | wc -l `
else
	flag=`netstat -apn | grep -w ${1} | grep -w LISTEN | wc -l`
fi
[ "${flag}X" == "X" ]  && flag=0
[ ${flag} -gt 0 ] && return 1
return 0
}


config_es_service(){
#1 work_dir
systemctl disable elasticsearch_dcvs.service > /dev/null 2>&1
cp -f ${1}/elasticsearch.service  /usr/lib/systemd/system/elasticsearch_dcvs.service
systemctl enable elasticsearch_dcvs.service
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




cur_time=`date +%Y%m%d%H%M%S`
cur_dir=$(cd `dirname $0`;pwd) 
config_file="${cur_dir}/config.param"
if test -r "${cur_dir}/env.conf" ; then 
source "${cur_dir}/env.conf"
fi