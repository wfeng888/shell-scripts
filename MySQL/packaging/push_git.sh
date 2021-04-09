#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh

g_mode="$1"
( [ "${g_mode}X" == "X" ]  || [ "${2}X" == "X" ]  || [ "${3}X" == "X" ] ) && echo "not all param has a value. " && exit 1
[ `check_between "${g_mode}"  "${G_MODE_VALUE}" "${G_MODE_GET}"` -eq 1 ] && echo "g_mode must between ${G_MODE_VALUE} or ${G_MODE_GET}. " && exit 1
if [ "${g_mode}" == "${G_MODE_VALUE}" ] ; then 
	git_commit_hash_value=`echo $2|cut -d '|' -f 1`
    #format:"yyyy-mm-dd hh24:mi:ss" 
    git_commit_timestamp=`echo $2|cut -d '|' -f 2`
else
    git_repo_dir=$2
    ( [ "${git_repo_dir}X" == "X" ] || [  ! -x  "${git_repo_dir}/.git" ] ) && echo "git_repo_dir was wrong. " && exit 1
	git_commit_hash_value=`git --git-dir "${git_repo_dir}/.git"  log -n1 --format=format:"%H"`
	git_commit_timestamp=`git --git-dir "${git_repo_dir}/.git" log -n1 --format=format:"%aI"`
fi
[ "${git_commit_hash_value}X" == "X" -o  "${git_commit_timestamp}X" == "X" ] && exit 1 
output_file=$3
cat >  ${output_file} << EOF
use metadata_schema;
insert into git_commit_hash(git_commit_hash,git_commit_date,remark)values('${git_commit_hash_value}','${git_commit_timestamp}','sync');
commit;
EOF
exit $?