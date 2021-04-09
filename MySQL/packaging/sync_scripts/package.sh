#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh


s_pv1=$1
s_pv2=$2

scripts_dirname="scripts"

push_git_file="${scripts_dirname}/PUSH_GITHASH.SQL"

msg_list_file_not_exists="list file not found ,exit with faild. "

work_dir="${cur_dir}/${cur_time}"

scripts_list="${scripts_dirname}.lst"
will_scripts_dir="${work_dir}/${scripts_dirname}"
mkdir -p "${work_dir}" && cd "${work_dir}"

 
tmp_list_file="${work_dir}/tmp_list.${cur_time}"
tmp_list_file1="${work_dir}/tmp_list1.${cur_time}"

if [ `file_is_empty "${list_file}" ` -eq 0 ] ; then 
    find ${git_project_path} -ipath ${git_project_path}/[0-9]*.SQL > "${tmp_list_file1}"
else
    cat "${list_file}" > "${tmp_list_file1}"
fi;

[ ! -e "${mysql_gz_software}" ] && echo "${pname_mysql_gz_software} does not exists." && exit 1

# 这里将所有文件路径全部转为绝对路径存储，避免有些操作系统不识别"path/../../path"这种相对路径
cat ${tmp_list_file1}|awk -v dir="${cur_dir}" 'BEGIN {result=""} /[\S]+/ {if ($1 !~ "^/") { result=dir"/"$1}  else { result=$1 } {  system("cd `dirname "result" `;pwd|xargs -I{} echo {}/`basename "result"`") }}' | xargs -I{} find -L {}  -iname *.SQL > ${tmp_list_file}

mkdir "${will_scripts_dir}"
xargs -a ${tmp_list_file} -I% sh -c "dirname %|cut -c 2- | xargs -I{} mkdir -p ${scripts_dirname}/{}; cp %  ${will_scripts_dir}%"
find ${scripts_dirname} -iname *.SQL > ${tmp_list_file}
level=`head -1  ${tmp_list_file}|awk -F'/' '{print NF}'`
let "level-=1"
type_index=${level}
let "level-=2"
version_index=${level}
sh ${cur_dir}/msort.sh ${tmp_list_file} ${version_index}  ${type_index}  ${type_string}  ${sortnum_delimiter}  ${scripts_list} 
pv0=
pv1=
pv2=
#将git hash值生成插入sql脚本并且附加到脚本列表中
if [  "${s_pv1}X" == "X" ] || [ "${s_pv2}X" == "X" ] ; then
	pv0="${G_MODE_GET}"
    pv1="${git_project_path}"
else
	pv0="${G_MODE_VALUE}"
	pv1="${git_hash}|${git_time}"
fi
pv2="${push_git_file}"
sh ${cur_dir}/push_git.sh  "${pv0}"  "${pv1}" "${pv2}"
[ $? -ne 0 -o ! -r "${push_git_file}"  -o  ! -s "${push_git_file}" ]  && exit 1

t_mysql_software=`echo ${mysql_gz_software##*/}`

echo "${push_git_file}" >> ${scripts_list}

echo "${pname_sync_ip}=" > config.param
echo "${pname_sync_port}=" >> config.param
echo "${pname_list_file}=${scripts_list}" >> config.param
echo "${pname_mysql_user}=" >> config.param
echo "${pname_mysql_passwd}=" >> config.param
echo "${pname_mysql_software_base}=" >> config.param
echo "${pname_ignore_error}=" >> config.param
echo "${pname_mysql_socket}=" >> config.param
echo "${pname_mysql_gz_software}=${t_mysql_software}" >> config.param
cp ${git_project_path}/packaging/sync_scripts/install.sh  install.sh
cp ${git_project_path}/packaging/sync_scripts/uninstall.sh  uninstall.sh
cp ${git_project_path}/packaging/sync_scripts/check.sh  check.sh
cp ${git_project_path}/packaging/sync_scripts/start.sh  start.sh
cp ${git_project_path}/packaging/sync_scripts/stop.sh   stop.sh
cp ${git_project_path}/packaging/sync_scripts/set_param.sh   set_param.sh
cp ${git_project_path}/packaging/sync_scripts/predefine.sh predefine.sh
#将mysql软件打包到sync包中，太垃圾了，都不想吐槽了
cp "${mysql_gz_software}"  ./
tar -czpvf  DCVSDBMYSQL_${cur_time}_MYSQLSYNC_DCVS.tar.gz   ${scripts_list} install.sh uninstall.sh check.sh start.sh stop.sh config.param predefine.sh ${scripts_dirname}  set_param.sh ${t_mysql_software}  --remove-files
