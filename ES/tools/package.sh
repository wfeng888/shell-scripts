#! /bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh


work_dir="${tmp_work_dir}"
mkdir -p ${work_dir}
{
export config_name=`echo ${config_file##*/}`
export software_gz_filename=`echo ${software_gz_path##*/}`
export es_version=`echo ${software_gz_filename}|cut -d '.' -f 1-3`
export es_version_num=`echo ${es_version##*-}`
export http_host="127.0.0.1"

export http_port=9600
export transport_port=9700



[ "${git_project_path}X" == "X" -o  "${software_gz_path}X" == "X"  -o  "${heap_size}X" == "X"  ] && echo " one or more  params is null ,please check " && exit 1

new_package_name="DCVSDBES_${cur_time}.${es_version_num}_ES_DCVS"
export es_dir="${work_dir}/${new_package_name}"

busy_flag=1
while [[ ${busy_flag} == 1 ]]
do
	check_port_busy ${http_port}
	if [ $? -ne 0 ]; then 
		let "http_port+=1"
	else
		busy_flag=0
	fi
done

busy_flag=1
while [[ ${busy_flag} == 1 ]]
do
	check_port_busy ${transport_port}
	if [ $? -ne 0 ]; then 
		let "transport_port+=1"
	else
		busy_flag=0
	fi
done

mkdir -p "${es_dir}/config"  "${es_dir}/data" "${es_dir}/logs"
mkdir -p "${es_dir}/scripts"  "${es_dir}/var" "${es_dir}/software"
tar -xzpvf ${software_gz_path} -C  "${es_dir}/software"

es_yml=
es_jvm=


[ ${cur_user} == ${os_user_root} ] && sh  "${cur_dir}/root_execute.sh" && [ $? -ne 0 ] && exit 1

if ! [ `grep -w ${os_user_group_es} /etc/group|cut -d ':' -f1`"X" == "${os_user_group_es}X" ] ; then 
    groupadd ${os_user_group_es}
fi
if ! [ `grep -w $os_user_es /etc/passwd|cut -d ':' -f1`"X" == "${os_user_es}X" ] ; then 
	useradd -d /home/${os_user_es} -m  -s/bin/bash -N -g${os_user_group_es}  ${os_user_es}
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


es_yml="${es_dir}/config/elasticsearch.yml"
es_jvm="${es_dir}/software/${es_version}/config/jvm.options"
es_jvm1="${es_dir}/config/jvm.options"

append_yml_value "path.data" "${es_dir}/data"
append_yml_value "path.logs" "${es_dir}/logs"
append_yml_value "cluster.name" "${cluster_name}"
append_yml_value "node.name" "$(hostname)"
append_yml_value "network.host" "${http_host}"
append_yml_value "transport.host" "${http_host}"
append_yml_value "transport.tcp.port" "${transport_port}"
append_yml_value "http.host" "${http_host}"
append_yml_value "http.port" "${http_port}"
append_yml_value "discovery.zen.minimum_master_nodes" "1"
append_yml_value "discovery.zen.ping.unicast.hosts" "${http_host}"
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
cp ${es_jvm} ${es_jvm1}



abs_base_dir=$(cd ${work_dir};pwd)
echo ${abs_base_dir%/}|awk -F '/' 'BEGIN{dirn="/"} {for(i=2;i<=NF;i++){dirn=(dirn""$i);print dirn;dirn=(dirn"/")} } '|xargs chmod o+x
cp ${git_project_path}/tools/start.sh  "${es_dir}/scripts/start.sh"
cp ${git_project_path}/tools/stop.sh  "${es_dir}/scripts/stop.sh"
cp "${es_dir}/software/${es_version}/config/log4j2.properties"   "${es_dir}/config/log4j2.properties"
chown -R ${os_user_es}:${os_user_group_es} ${work_dir}
chmod u+x "${es_dir}/scripts/start.sh"
chmod u+x "${es_dir}/scripts/stop.sh"

su_execute "${es_dir}/scripts/start.sh"  

common_waittimeout 60 "check_es_alive"
sleep 30
[ $? -ne 0 -o ! -f "${es_dir}/var/pid" -o `cat "${es_dir}/var/pid" |xargs ps -p|grep -v PID|wc -l ` -lt 1 ] && echo "start elasticsearch instance failed !" && exit 1

cp ${git_project_path}/tools/deploy.sh  ${cur_dir}/deploy.sh
sh  ${cur_dir}/deploy.sh

su -l ${os_user_es} -c "${es_dir}/scripts/stop.sh"
common_waittimeout 120  "check_es_stop"
[ `check_es_stop` -eq 1 ]  && echo "es instance stop failed , exit with failed !" && exit 1

cd ${work_dir}
cat  /dev/null > "./${config_name}" 
update_config_file "${pname_package_name}" "$new_package_name"  "./${config_name}" 
update_config_file "${pname_running_mode}" "SINGLE"  "./${config_name}"
update_config_file "$pname_network_host"  ""  "./${config_name}"
update_config_file "$pname_http_host"  ""  "./${config_name}"
update_config_file "$pname_http_port"  ""  "./${config_name}"
update_config_file "$pname_transport_host"  ""  "./${config_name}"
update_config_file "$pname_transport_tcp_port"  ""  "./${config_name}"
update_config_file "$pname_heap_size"  "2"  "./${config_name}"
update_config_file "$pname_base_dir"  "/bigdata/dcvs/es"  "./${config_name}"
update_config_file "$pname_cluster_name"  "faraday-es.znv.com"  "./${config_name}"
update_config_file "$pname_es_version"  "${es_version}"  "./${config_name}"
remove_config "${pname_git_project_path}"  "./${config_name}"

rsync -r --exclude=.git ${git_project_path} "./${new_package_name}/"

tar -cvpf  ${new_package_name}.tar  ${new_package_name}  --remove-files > /dev/null
cp ${git_project_path}/tools/install.sh  install.sh
cp ${git_project_path}/tools/root_execute.sh root_execute.sh
cp ${git_project_path}/tools/start_service.sh start.sh
cp ${git_project_path}/tools/stop_service.sh stop.sh
cp ${git_project_path}/tools/uninstall.sh uninstall.sh
cp ${git_project_path}/tools/predefine.sh predefine.sh
cp ${git_project_path}/tools/set_param.sh set_param.sh
cp ${git_project_path}/tools/check.sh check.sh
cp ${git_project_path}/tools/elasticsearch.service elasticsearch.service

tar -czpvf  ${new_package_name}.tar.gz ${new_package_name}.tar install.sh  root_execute.sh  ${config_name} \
     start.sh stop.sh uninstall.sh predefine.sh set_param.sh check.sh elasticsearch.service  --remove-files
echo "packaging success !"
} > ${work_dir}/package.log.${cur_time}
echo "packaging success !"
