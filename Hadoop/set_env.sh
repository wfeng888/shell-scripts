#!/bin/bash
# for hadoop version 2.10.1
#placed in /etc/profile.d/
basedir="/home/bigdata/hadoop/public"
hdfs_basedir="/home/bigdata/hadoop/hdfs"
yarn_basedir="/home/bigdata/hadoop/yarn"
mapred_basedir="/home/bigdata/hadoop/mapred"

# for public
JAVA_HOME="/usr/java/java-se-7u75-ri"
CLASS_PATH=".:${JAVA_HOME}/lib/dt.jar:${JAVA_HOME}/lib/tools.jar:${JAVA_HOME}/lib/sa-jdi.jar:${JAVA_HOME}/lib/jconsole.jar"
HADOOP_HOME="/usr/local/hadoop-stable"
HADOOP_PREFIX="${HADOOP_HOME}"
HADOOP_CLASSPATH="${CLASS_PATH}"
HADOOP_CLIENT_OPTS=""
HADOOP_SECURE_DN_USER=""
HADOOP_PID_DIR=${hdfs_basedir}/var
HADOOP_LOG_DIR=${hdfs_basedir}/log
HADOOP_HEAPSIZE=2048


# for hdfs daemon
HADOOP_CONF_DIR="${basedir}/etc/hadoop"

# for NameNode
HADOOP_NAMENODE_OPTS="-XX:+UseParallelGC"


# for SecondaryNameNode
HADOOP_SECONDARYNAMENODE_OPTS=""

# for DataNode
HADOOP_DATANODE_OPTS=""


# for yarn daemon
YARN_HEAPSIZE=2048
HADOOP_YARN_HOME="${HADOOP_HOME}"
HADOOP_YARN_USER=yarn
YARN_CONF_DIR="${basedir}/etc/hadoop"
YARN_LOG_DIR="${yarn_basedir}/log"
YARN_POLICYFILE=""
YARN_OPTS=""
JAVA_LIBRARY_PATH=""
YARN_ROUTER_OPTS=""

#for yarn_resourcemanager
YARN_RESOURCEMANAGER_OPTS=""
YARN_RESOURCEMANAGER_HEAPSIZE=2048

#for yarn_nodemanager
YARN_NODEMANAGER_OPTS=""
YARN_NODEMANAGER_HEAPSIZE=2048

#for yarn_proxyserver
YARN_PROXYSERVER_OPTS=""
YARN_PROXYSERVER_HEAPSIZE=2048



#for mapreduce daemon

#for job_historyserver
HADOOP_JOB_HISTORYSERVER_OPTS=""
HADOOP_JOB_HISTORYSERVER_HEAPSIZE=2048
HADOOP_MAPRED_PID_DIR="${mapred_basedir}/var"
HADOOP_MAPRED_LOG_DIR="${mapred_basedir}/log"