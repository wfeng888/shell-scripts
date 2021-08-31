#! /bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh

#pname_drop_before_deploy="drop_before_deploy"
#drop_before_deploy=`get_value ${pname_drop_before_deploy} ${config_file}`



cd "${git_project_path}"
find . -iname *.json > "tmp_sort.${cur_time}"
level=`head -1  "tmp_sort.${cur_time}"|awk -F'/' '{print NF}'`
let "level-=1"
type_index=${level}
let "level-=1"
version_index=${level}
sh ${cur_dir}/msort.sh  "tmp_sort.${cur_time}"  ${version_index}  ${type_index}  "${type_string}"  "${sortnum_delimiter}"  "sorted.${cur_time}"
while read s_file
do
sh ${cur_dir}/recreate.sh ${s_file}  ${http_host}  ${http_port}
[ $? -ne 0 ] && exit 1
done < "sorted.${cur_time}"
exit 0