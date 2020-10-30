#! /bin/bash
cur_dir=$(cd `dirname $0`;pwd)
source ${cur_dir}/set_param.sh
cd ${cur_dir}

es_yml=
es_jvm=


[ ${cur_user} == ${os_user_root} ] && sh  "${cur_dir}/root_execute.sh" && [ $? -ne 0 ] && exit 1

if ! [ `grep -w ${os_user_group_es} /etc/group|cut -d ':' -f1`"X" == "${os_user_group_es}X" ] ; then 
    groupadd ${os_user_group_es}
fi
if ! [ `grep -w $os_user_es /etc/passwd|cut -d ':' -f1`"X" == "${os_user_es}X" ] ; then 
	useradd -d /home/${os_user_es} -m  -s/bin/bash -N -g${os_user_group_es}  ${os_user_es}
#passwd ${os_user_es} <<EOF
#${os_user_es}
#${os_user_es}
#EOF
	chown -R ${os_user_es}:${os_user_group_es} /home/${os_user_es}
else
	os_user_group_es=`id -gn ${os_user_es}`
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

[ ${base_dir}X == "X" ] && base_dir=${cur_dir}
[ ${cluster_name}X == "X" ] && cluster_name=$cur_time
success=1
if [ ! -d $base_dir ] ; then 
	success=0 
	sudo_execute "mkdir -p $base_dir" "o"
	if [ $? == 0 ] ; then 
		sudo_execute "chown -R $os_user_es:${os_user_group_es} $base_dir" "o"
		if [ $? == 0 ] ; then 
			success=1
		fi
	fi
fi
[  ${success} == 0 ] && echo "prepareing environment failed,exit 1" && exit 1

[ -d "$base_dir/${package_name}" ] && mv "$base_dir/${package_name}" "$base_dir/${package_name}.${cur_time}"
  
tar -xpvf $package_gz_file -C $base_dir > /dev/null
cd $base_dir
chown -R ${os_user_es}:${os_user_group_es} $package_name
es_yml="${base_dir}/${package_name}/config/elasticsearch.yml"
es_jvm="${base_dir}/${package_name}/software/${es_version}/config/jvm.options"
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
append_yml_value "discovery.zen.ping.unicast.hosts" "${transport_host}"
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

replace_infile "${cur_dir}/start.sh"
replace_infile "${cur_dir}/stop.sh"
replace_infile "${cur_dir}/uninstall.sh"
replace_infile "${cur_dir}/elasticsearch.service"
config_es_service  "${cur_dir}"
cp "${cur_dir}/start.sh"  "${base_dir}/${package_name}/scripts/start_service.sh"
cp "${cur_dir}/stop.sh"  "${base_dir}/${package_name}/scripts/stop_service.sh"
cp "${cur_dir}/uninstall.sh"  "${base_dir}/${package_name}/scripts/uninstall.sh"

echo "success!"
exit 0


