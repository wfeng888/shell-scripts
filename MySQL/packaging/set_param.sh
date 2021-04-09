#!/bin/bash
check_between(){
local i=1
first_param=
[ "${1}X" == "X" ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return;
let "i+=1"
done
echo 1
}



cur_dir=$(cd `dirname $0`;pwd) 
G_MODE_VALUE='VALUE'
G_MODE_GET='GET'




