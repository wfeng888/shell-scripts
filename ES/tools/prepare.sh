#! /bin/bash

check_project_not_exist(){
#1 project_name
local project_name=$1
[ ! -f  "${projectFilePath}/${project_name}.es" ] && echo  0 && return 0
echo 1
}

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

check_between(){
local i=1
first_param=
[ ! $1 ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return 0;
let "i+=1"
done
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

check_es_alive(){
local is_alive=`netstat -apn|grep -w ${http_port}|grep -w LISTEN|wc -l`
[ ${is_alive} -eq 1 ] && echo 0 && return 0
echo 1 && return 0
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

cur_dir=$(cd `dirname $0`;pwd)
cd ${cur_dir}
cur_time=`date +%Y-%m-%d-%H-%M-%S`
#pname_project_name="project_name"
pname_base_dir="base_dir"
pname_network_host="network_host"
pname_http_host="http_host"
pname_http_port="http_port"
pname_transport_host="transport_host"
pname_transport_tcp_port="transport_tcp_port"
pname_heap_size="heap_size"
pname_running_mode="running_mode"
pname_package_name="package_name"
pname_cluster_name="cluster_name"
pname_es_version="es_version"

[ "${1}X" != "X" ] && config_file=$1
[ "${config_file}X" == "X" ] && config_file="${cur_dir}/config.param"





#export project_name=`get_param_value ${pname_project_name}  ${config_file} `
export base_dir=`get_param_value ${pname_base_dir}  ${config_file} `
export network_host=`get_param_value ${pname_network_host}  ${config_file} `
export http_host=`get_param_value ${pname_http_host}  ${config_file} `
export http_port=`get_param_value ${pname_http_port}  ${config_file} `
export transport_host=`get_param_value ${pname_transport_host}  ${config_file} `
export transport_tcp_port=`get_param_value ${pname_transport_tcp_port}  ${config_file} `
export heap_size=`get_param_value ${pname_heap_size}  ${config_file} `
export package_name=`get_param_value ${pname_package_name}  ${config_file} `
export cluster_name=`get_param_value ${pname_cluster_name}  ${config_file} `
export es_version=`get_param_value ${pname_es_version}  ${config_file} `
running_mode=SINGLE

export os_user_es="elasticsearch"
export os_user_group_es="elastic"
export os_user_root="root"
export cur_user=`id -un`
package_gz_file=$package_name".tar"


es_yml=
es_jvm=



[  `check_between  ${cur_user}  ${os_user_root}  ${os_user_es}` -eq 1 ]  && echo "execute user must be elasticsearch or root ! " && exit 1;

[ ${cur_user} == ${os_user_root} ] && sh  "${cur_dir}/root_execute.sh" && [ $? -ne 0 ] && exit 1

if ! [ `grep -w os_user_group_es /etc/group|cut -d ':' -f1`"X" == "${os_user_group_es}X" ] ; then 
    groupadd ${os_user_group_es}
fi
if ! [ `grep -w $os_user_es /etc/passwd|cut -d ':' -f1`"X" == "${os_user_es}X" ] ; then 
	useradd -d /home/${os_user_es} -m -p${os_user_es} -s/bin/bash -N -g${os_user_group_es}  ${os_user_es}
passwd ${os_user_es} <<EOF
${os_user_es}
${os_user_es}
EOF
	chown -R ${os_user_es}:${os_user_group_es} /home/${os_user_es}
fi

#"ulimit -n 65536"
#"ulimit -l unlimited"
#"ulimit -u 2048"
un=`su_execute "ulimit -n" `
ul=`su_execute "ulimit -l" `
uu=`su_execute "ulimit -u" `
[ ! $un ] && un=1
[ ! $ul ] && ul=1
[ ! $uu ] && uu=1
if [ "${un}X" == "X" -o "${ul}X" == "X" -o "${uu}X" == "X" -o ${un} != "unlimited" -a ${un} -lt 65536  -o ${ul} != "unlimited"  -o ${uu} != "unlimited" -a ${uu} -lt 2048  ] ; then 
echo "need set ulimit configurations , you must run root_execute.sh using root user first."
exit 1
fi
sudo_execute "sysctl -w vm.max_map_count=262144" "o"
vm=`sysctl -ne  vm.max_map_count`
[ ! $vm ] && vm=1
if [ "${vm}X" == "X" -o  ${vm} -lt 262144 ]; then 
echo "need set vm.max_map_count configurations , you must run root_execute.sh using root user first."
exit 1
fi

check_port_busy ${http_port}
[ $? -ne 0 ] && echo " http_port ${http_port} is busy or sudo failed, exit with errors .please check !" && exit 1
check_port_busy ${transport_tcp_port}
[ $? -ne 0 ] && echo " transport_tcp_port ${transport_tcp_port} is busy or sudo failed, exit with errors  .please check !" && exit 1

[ ${base_dir}X == "X" ] && base_dir=${cur_dir}
[ ${cluster_name}X == "X" ] && cluster_name=$cur_time
success=1
if [ ! -d $base_dir ] ; then 
	success=0 
	sudo_execute "mkdir -p $base_dir" "o"
	if [ $? == 0 ] ; then 
		sudo_execute "chown -R $os_user_es:$os_user_es $base_dir" "o"
		if [ $? == 0 ] ; then 
			success=1
		fi
	fi
fi
[  ${success} == 0 ] && echo "prepareing environment failed,exit 1" && exit 1
	
cp $package_gz_file  $base_dir
cd $base_dir
[ -d "$base_dir/${package_name}" ] && mv "$base_dir/${package_name}" "$base_dir/${package_name}.${cur_time}"  
tar -xpvf $package_gz_file > /dev/null
chown -R ${os_user_es}:${os_user_es} $package_name
export es_yml="${base_dir}/${package_name}/config/elasticsearch.yml"
export es_jvm="${base_dir}/${package_name}/software/${es_version}/config/jvm.options"
[ -d "${base_dir}/${package_name}/logs" ] && rm -f ${base_dir}/${package_name}/logs/*.log


mv ${es_yml} "${es_yml}.${cur_time}"
 
append_yml_value "path.data" "${base_dir}/${package_name}/data"
append_yml_value "path.logs" "${base_dir}/${package_name}/logs"
append_yml_value "cluster.name" "${cluster_name}"
append_yml_value "node.name" "$(hostname)"
append_yml_value "network.host" "${network_host}"
append_yml_value "transport.host" "${transport_host}"
append_yml_value "transport.tcp.port" "${transport_tcp_port}"
append_yml_value "http.host" "${http_host}"
append_yml_value "http.port" "${http_port}"
append_yml_value "discovery.zen.minimum_master_nodes" "1"
append_yml_value "discovery.zen.ping.unicast.hosts" "${transport_host}#"
append_yml_value "node.attr.cname" "$(hostname)"
append_yml_value "cluster.routing.allocation.awareness.attributes" "cname"
append_yml_value "node.master" "true"
append_yml_value "node.data" "true"
append_yml_value "node.ingest" "true"
append_yml_value "gateway.recover_after_nodes" "1"
append_yml_value "gateway.expected_nodes" "1"
append_yml_value "gateway.recover_after_time" "5m"
append_yml_value "action.auto_create_index" "false"

sed -r -i -e "s="'^\s*-Xms[0-9]+g\s*$'"=-Xms${heap_size}g=" -e  "s="'^\s*-Xmx[0-9]+g\s*$'"=-Xmx${heap_size}g=" ${es_jvm}
abs_base_dir=$(cd ${base_dir};pwd)
echo ${abs_base_dir%/}|awk -F '/' 'BEGIN{dirn="/"} {for(i=2;i<=NF;i++){dirn=(dirn""$i);print dirn;dirn=(dirn"/")} } '|xargs chmod o+x
su_execute "${base_dir}/${package_name}/scripts/start.sh"  

common_waittimeout 60 "check_es_alive"
sleep 30
[ $? -ne 0 -o ! -f "${base_dir}/${package_name}/var/pid" -o `cat "${base_dir}/${package_name}/var/pid" |xargs ps -p|grep -v PID|wc -l ` -lt 1 ] && echo "start elasticsearch instance failed !" && exit 1

echo "success!"
exit 0


