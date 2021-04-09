#!/bin/bash

compare(){
local v1=$1
local v2=$2
if [[ "$v1" =~ ^rhbb_ ]]; then
v1=`echo ${v1}|cut -c 6-`
fi
if [[ "$v2" =~ ^rhbb_ ]]; then
v2=`echo ${v2}|cut -c 6-`
fi
if (( "$v1 < $v2" )) ;then
echo -1
elif (( "$v1 > $v2" )) ;then
echo 1
else
echo 0
fi
}


#1 list_file
#2 version_index
#3 type_index
#4 type_string
#5 sortnum_delimiter
#6 output_file

list_file=$1
version_index=$2
type_index=$3
type_string=$4
sortnum_delimiter=$5
output_file=$6

unset types
declare $(echo "${type_string}"| awk  -F ';' 'BEGIN{i=1;k=0;} {for(;i<=NF;i++&&k++){printf("types[%d]=%s  ",k,$i)}}')



files[0]=
file_seq=0
while read file_name 
do

num=$file_seq
let "file_seq+=1"
current_seq=$num

files[${current_seq}]=${file_name}
[ ${current_seq} -eq 0 ] && continue 



version=`echo "${file_name}" |cut -d'/' -f ${version_index}`
unset versions
declare $(echo "${version}"| awk  -F '.' 'BEGIN{i=1;k=0;} {for(;i<=NF;i++&&k++){printf("versions[%d]=%s  ",k,$i)}}')
type=`echo "${file_name}" |cut -d'/' -f ${type_index}`
sort_n=`echo "${file_name##*/}"|cut -d${sortnum_delimiter} -f 1`

type_num=2
for(( i=0;i<${#types[@]};i++)) 
do
if [ `echo ${type}|tr a-z A-Z` ==  ${types[i]} ] ; then 
	type_num=i
	let "type_num+=1"
	break
fi
done;

#[ `echo ${type}|tr a-z A-Z` == 'TABLES' ] && type_num=1
#[ `echo ${type}|tr a-z A-Z` == 'DML' ] && type_num=3

last_seq=${num}
let "last_seq-=1"
tmp_last_seq=${last_seq}
last_version=
last_type=
last_type_num=
last_sort_n=


tmp_current_seq=$num
while (( ${tmp_current_seq} > 0 ))
do
current_seq=${tmp_current_seq}
last_seq=${tmp_last_seq}
let "tmp_current_seq-=1"
let "tmp_last_seq-=1"

switch_flag=0
version_flag=0

last_version=`echo ${files[${last_seq}]}|cut -d '/' -f ${version_index}`
last_type=`echo ${files[${last_seq}]}|cut -d '/' -f ${type_index}`
last_sort_n=`echo ${files[${last_seq}]##*/}|cut -d${sortnum_delimiter} -f 1`
unset last_versions
declare $(echo "${last_version}"| awk  -F '.' 'BEGIN{i=1;k=0;} {for(;i<=NF;i++&&k++){printf("last_versions[%d]=%s  ",k,$i)}}')

#for i in ${versions[*]} ; do echo $i ; done

versuib_num=${#versions[@]}
last_versuib_num=${#last_versions[@]}
compare_versuib_num=${versuib_num}
if (( "${last_versuib_num} < ${compare_versuib_num}" )) ; then 
compare_versuib_num=${last_versuib_num}
fi


for (( i=0 ; i<${compare_versuib_num} ; i++ )) {
com_flag=`compare ${versions[i]} ${last_versions[i]}`
if [ $com_flag -lt 0 ] ;then
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1
break;
elif [ $com_flag -gt 0 ] ;then 
version_flag=1
break;
fi;
}

if (( "${versuib_num} > ${last_versuib_num}" )) ; then 
	version_flag=1
fi;

[ ${switch_flag} -eq 1 ] && continue
[ ${version_flag} -eq 1 ] && break

if (( "${versuib_num} < ${last_versuib_num}" )) ; then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1
fi
[ ${switch_flag} -eq 1 ] && continue

last_type_num=2
#[ `echo ${last_type}|tr a-z A-Z` == 'TABLES' ] && last_type_num=1
#[ `echo ${last_type}|tr a-z A-Z` == 'DML' ] && last_type_num=3
for(( i=0;i<${#types[@]};i++)) 
do
if [ `echo ${last_type}|tr a-z A-Z` ==  ${types[i]} ] ; then 
	last_type_num=i
	let "last_type_num+=1"
	break
fi
done;

if [ ${type_num} -lt ${last_type_num} ] ;then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1;
continue;
fi;

if [ ${type_num} -gt ${last_type_num} ] ;then 
    break;
fi;

#echo ${sort_n}
#echo ${last_sort_n}
if (( 10#${sort_n} < 10#${last_sort_n} )) ;then 
files[${current_seq}]=${files[${last_seq}]}
files[${last_seq}]=${file_name}
switch_flag=1;
continue;
fi;
[ ${switch_flag} -eq 0 -o ${tmp_last_seq} -lt 0 ] && break 
done 

done < ${list_file}

cat /dev/null > ${output_file}
for(( i=0;i<${#files[@]};i++)) 
do
echo  "${files[i]}" >> ${output_file}
done;