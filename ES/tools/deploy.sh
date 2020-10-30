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
#[ `echo ${s_file} | grep -E '^\s*\S*\.[Jj][Ss][Oo][Nn]\s*$' |wc -l ` -eq 0 ] && continue
unset  real_file
#unset format_file
#format_file=`echo ${s_file} |sed 's=\s*==g'`
real_file=${s_file##*/}
real_file=${real_file%.json}
oper=`echo $real_file|cut -d '#' -f 2`
name=`echo $real_file|cut -d '#' -f 3- | sed 's=#=/=g'`

#if [ `echo "${drop_before_deploy}X"|tr a-z A-Z` == "YX"  -a `echo "${oper}X"|tr a-z A-Z == "PUTX"`  ] ; then
#curl -X DELETE "${http_host}:${http_port}/${name}"
#fi
echo "addr: ${http_host}:${http_port}/${name} , file: ${s_file}  ."
curl -X $oper "${http_host}:${http_port}/${name}?pretty" -H 'Content-Type: application/json' -d@${s_file}
done < "sorted.${cur_time}"