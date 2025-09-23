FROM openjdk:8-jdk-slim

# Instalar dependencias necesarias
RUN apt-get update && apt-get install -y \
    curl \
    ssh \
    rsync \
    netcat \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Instalar AWS CLI para interactuar con MinIO
RUN pip3 install awscli

# Variables de entorno para Hadoop
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
ENV HDFS_NAMENODE_USER=root
ENV HDFS_DATANODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root

# Descargar e instalar Hadoop
RUN curl -L https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | \
    tar -xz -C /opt/ && \
    mv /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME}

# Copiar configuraciones
COPY config/*.xml ${HADOOP_CONF_DIR}/

# Copiar script de entrada
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Crear directorios necesarios
RUN mkdir -p /hadoop/dfs/name /hadoop/dfs/data /shared/jars

# Exponer puertos
EXPOSE 9870 9864 8088 8030 8031 8032 8033 8040 8042

ENTRYPOINT ["/entrypoint.sh"]
