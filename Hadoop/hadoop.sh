#!/bin/bash
# for hadoop version 2.10.1
#placed in /etc/profile.d/
basedir="/home/bigdata/hadoop/public"
hdfs_basedir="/home/bigdata/hadoop/hdfs"
yarn_basedir="/home/bigdata/hadoop/yarn"
mapred_basedir="/home/bigdata/hadoop/mapred"

# for public
export JAVA_HOME="/usr/java/java-se-7u75-ri"
export CLASS_PATH=".:${JAVA_HOME}/lib/dt.jar:${JAVA_HOME}/lib/tools.jar:${JAVA_HOME}/lib/sa-jdi.jar:${JAVA_HOME}/lib/jconsole.jar"
export HADOOP_HOME="/usr/local/hadoop-stable"
export HADOOP_PREFIX="${HADOOP_HOME}"
export HADOOP_CLASSPATH="${CLASS_PATH}"
export HADOOP_CLIENT_OPTS=""
export HADOOP_SECURE_DN_USER=""
export HADOOP_PID_DIR=${hdfs_basedir}/var
export HADOOP_LOG_DIR=${hdfs_basedir}/log
export HADOOP_HEAPSIZE=2048


# for hdfs daemon
export HADOOP_CONF_DIR="${basedir}/etc/hadoop"

# for NameNode
export HADOOP_NAMENODE_OPTS="-XX:+UseParallelGC"


# for SecondaryNameNode
export HADOOP_SECONDARYNAMENODE_OPTS=""

# for DataNode
export HADOOP_DATANODE_OPTS=""


# for yarn daemon
export YARN_HEAPSIZE=2048
export HADOOP_YARN_HOME="${HADOOP_HOME}"
export HADOOP_YARN_USER=yarn
export YARN_CONF_DIR="${basedir}/etc/hadoop"
export YARN_LOG_DIR="${yarn_basedir}/log"
export YARN_POLICYFILE=""
export YARN_OPTS=""
export JAVA_LIBRARY_PATH=""
export YARN_ROUTER_OPTS=""

#for yarn_resourcemanager
export YARN_RESOURCEMANAGER_OPTS=""
export YARN_RESOURCEMANAGER_HEAPSIZE=2048

#for yarn_nodemanager
export YARN_NODEMANAGER_OPTS=""
export YARN_NODEMANAGER_HEAPSIZE=2048

#for yarn_proxyserver
export YARN_PROXYSERVER_OPTS=""
export YARN_PROXYSERVER_HEAPSIZE=2048



#for mapreduce daemon

#for job_historyserver
export HADOOP_JOB_HISTORYSERVER_OPTS=""
export HADOOP_JOB_HISTORYSERVER_HEAPSIZE=2048
export HADOOP_MAPRED_PID_DIR="${mapred_basedir}/var"
export HADOOP_MAPRED_LOG_DIR="${mapred_basedir}/log"