#! /bin/bash
file=$1
http_host=$2
http_port=$3
while read filename
do
echo $filename
./recreate.sh $filename "$http_host"  "$http_port"
done<${file}
