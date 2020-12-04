#!/bin/bash
# for hadoop-env.sh
cpwd=$(cd `dirname $0`;pwd)
basedir="${cpwd%/*}"

# for public
export JAVA_HOME=""
export HADOOP_HOME=""
export HADOOP_CLASSPATH=""
export HADOOP_CLIENT_OPTS=""
export HADOOP_SECURE_DN_USER=""
export HADOOP_CONF_DIR="${basedir}/etc/hadoop"
export HADOOP_PID_DIR=${basedir}/var
export HADOOP_LOG_DIR=${basedir}/log
export YARN_HEAPSIZE=2048
export HADOOP_HEAPSIZE=2048


# for NameNode
export HADOOP_NAMENODE_OPTS="-XX:+UseParallelGC"


# for SecondaryNameNode
export HADOOP_SECONDARYNAMENODE_OPTS=""

# for DataNode
export HADOOP_DATANODE_OPTS=""


#for yarn_resourcemanager
export YARN_RESOURCEMANAGER_OPTS=""
export YARN_RESOURCEMANAGER_HEAPSIZE=2048

#for yarn_nodemanager
export YARN_NODEMANAGER_OPTS=""
export YARN_NODEMANAGER_HEAPSIZE=2048

#for yarn_proxyserver
export YARN_PROXYSERVER_OPTS=""
export YARN_PROXYSERVER_HEAPSIZE=2048

#for job_historyserver
export HADOOP_JOB_HISTORYSERVER_OPTS=""
export HADOOP_JOB_HISTORYSERVER_HEAPSIZE=2048