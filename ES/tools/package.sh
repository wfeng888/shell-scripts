#! /bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh


work_dir="${tmp_work_dir}"
mkdir -p ${work_dir}
{
config_name=`echo ${config_file##*/}`
es_version_num=`echo ${es_version##*-}`


[ "${git_project_path}X" == "X" -o "${running_mode}X" == "X" -o "${http_host}X" == "X" -o "${http_port}X" == "X" ] && echo " one or more  params is null ,please check " && exit 1

new_package_name="DCVSDBES_${cur_time}.${es_version_num}_ES_DCVS"
cd $base_dir
if [ ${running_mode} == 'SINGLE' ];then
is_alive=`netstat -apn|grep -w ${http_port}|grep -w LISTEN|wc -l`
if [ ${is_alive} -gt 0 ];then 
	netstat -apn|grep -w ${http_port}|grep -w LISTEN|sed 's= \{1,\}= ='g|cut -d' ' -f7|cut -d'/' -f1| xargs pkill  
fi
mv "${base_dir}/${package_name}/data" "${base_dir}/${package_name}/data.bak.${cur_time}"
mkdir -p "${base_dir}/${package_name}/data"
chown ${os_user_es}:${os_user_es}  "${base_dir}/${package_name}/data"
su -l ${os_user_es} -c "${base_dir}/${package_name}/scripts/start.sh"
common_waittimeout 120 "check_es_alive"
[ `check_es_alive` -eq 1 ] && echo "es instance not running and can not be started . exit with failed !" && exit 1
sleep 10

cp ${git_project_path}/tools/deploy.sh  deploy.sh
sh  ${cur_dir}/deploy.sh

su -l ${os_user_es} -c "${base_dir}/${package_name}/scripts/stop.sh"
common_waittimeout 120  "check_es_stop"
[ `check_es_stop` -eq 1 ]  && echo "es instance stop failed , exit with failed !" && exit 1

cd ${work_dir}

rsync -r --exclude=data.bak.* "${base_dir}/${package_name}"  "./"
cp ${git_project_path}/tools/start.sh  "${package_name}/scripts/start.sh"
cp ${git_project_path}/tools/stop.sh  "${package_name}/scripts/stop.sh"

cp ${config_file} "./"
update_config_file "${pname_package_name}" "$new_package_name"  "./${config_name}" 
update_config_file "${pname_running_mode}" "SINGLE"  "./${config_name}"
update_config_file "$pname_network_host"  ""  "./${config_name}"
update_config_file "$pname_http_host"  ""  "./${config_name}"
update_config_file "$pname_http_port"  ""  "./${config_name}"
update_config_file "$pname_transport_host"  ""  "./${config_name}"
update_config_file "$pname_transport_tcp_port"  ""  "./${config_name}"
update_config_file "$pname_heap_size"  "2"  "./${config_name}"
update_config_file "$pname_base_dir"  "/bigdata/dcvs/es"  "./${config_name}"
update_config_file "$pname_cluster_name"  "dcvs-es-${es_version_num}"  "./${config_name}"
remove_config "${pname_git_project_path}"  "./${config_name}"

rsync -r --exclude=.git ${git_project_path} "./${package_name}/"
mv "${package_name}"  "${new_package_name}"
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
#rm -f ${new_package_name}.tar install.sh  root_execute.sh  ${config_name} \
#     start.sh stop.sh uninstall.sh predefine.sh set_param.sh check.sh elasticsearch.service \
#	 ${new_package_name} 
#mv ${new_package_name}.tar.gz ../
#cd ..
#rm -fr ${work_dir}
fi
echo "packaging success !"
} > ${work_dir}/package.log.${cur_time}
echo "packaging success !"
