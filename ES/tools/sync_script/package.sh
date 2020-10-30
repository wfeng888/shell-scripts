#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh

scripts_dirname="scripts"

msg_list_file_not_exists="list file not found ,exit with faild. "

work_dir="${cur_dir}/${cur_time}"

scripts_list="${scripts_dirname}.lst"
will_scripts_dir="${work_dir}/${scripts_dirname}"
mkdir -p "${work_dir}" && cd "${work_dir}"

 
tmp_list_file="${work_dir}/tmp_list.${cur_time}"

[ `file_is_empty "${list_file}" ` -eq 0 ] && find ${git_project_path} -ipath ${git_project_path}/[0-9]*.JSON > "${list_file}"
# 这里将所有文件路径全部转为绝对路径存储，避免有些操作系统不识别"path/../../path"这种相对路径
cat ${list_file}|awk -v dir="${cur_dir}" 'BEGIN {result=""} {if ($1 !~ "^/") { result=dir"/"$1}  else { result=$1 } {  system("cd `dirname "result" `;pwd|xargs -I{} echo {}/`basename "result"`") }}' | xargs -I{} find -L {}  -iname *.JSON > ${tmp_list_file}

mkdir "${will_scripts_dir}"
xargs -a ${tmp_list_file} -I% sh -c "dirname %|cut -c 2- | xargs -I{} mkdir -p scripts/{}; cp %  ${will_scripts_dir}%"
find ${scripts_dirname} -iname *.JSON > ${tmp_list_file}
level=`head -1  ${tmp_list_file}|awk -F'/' '{print NF}'`
let "level-=1"
type_index=${level}
let "level-=1"
version_index=${level}
sh ${cur_dir}/msort.sh ${tmp_list_file} ${version_index}  ${type_index}  ${type_string}  ${sortnum_delimiter}  ${scripts_list} 
echo "${pname_sync_es_http_ip}=" > config.param
echo "${pname_sync_es_http_port}=" >> config.param
echo "${pname_cluster_name}=" >> config.param
echo "${pname_list_file}=${scripts_list}" >> config.param
cp ${git_project_path}/tools/sync_script/install.sh  install.sh
cp ${git_project_path}/tools/sync_script/uninstall.sh  uninstall.sh
cp ${git_project_path}/tools/sync_script/check.sh  check.sh
cp ${git_project_path}/tools/sync_script/start.sh  start.sh
cp ${git_project_path}/tools/sync_script/stop.sh   stop.sh
cp ${git_project_path}/tools/sync_script/set_param.sh   set_param.sh
cp ${git_project_path}/tools/predefine.sh predefine.sh
cp ${git_project_path}/tools/recreate.sh recreate.sh
tar -czpvf  DCVSDBES_${cur_time}_ESSYNC_DCVS.tar.gz   ${scripts_list} install.sh uninstall.sh check.sh start.sh stop.sh config.param predefine.sh recreate.sh ${scripts_dirname}  set_param.sh  --remove-files
