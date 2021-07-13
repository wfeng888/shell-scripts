#!/bin/bash
pid=$1
mhcache=/database/hcache

if [ -f /tmp/cache.files ]
then
    echo "the cache.files is exist, removing now "
    rm -f /tmp/cache.files
fi

if [  "${pid}X" == "X" ] ; then 
	#find the top 3 processs' cache file
	ps -e -o pid,rss|sort -nk2 -r|head -10 |awk '{print $1}'>/tmp/cache.pids	
else
	echo "${pid}" > /tmp/cache.pids
fi

while read line
do
    lsof -p $line 2>/dev/null |grep -v '\.ibd'|awk '{print $9}' >>/tmp/cache.files 
done</tmp/cache.pids


if [ -f /tmp/cache.hcache ]
then
    echo "the cache.hcache is exist, removing now"

    rm -f /tmp/cache.hcache
fi

for i in `cat /tmp/cache.files`
do

    if [ -f $i ]
    then

        echo $i >>/tmp/cache.hcache
    fi
done

${mhcache} -terse `cat /tmp/cache.hcache`

rm -f /tmp/cache.{pids,files,hcache}