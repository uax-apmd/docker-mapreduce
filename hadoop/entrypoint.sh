#!/bin/bash

# Variables de entorno adicionales para MapReduce
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"

# Función para esperar a que un servicio esté disponible
wait_for_service() {
    host=$1
    port=$2
    echo "Esperando a que $host:$port esté disponible..."
    while ! nc -z $host $port; do
        sleep 1
    done
    echo "$host:$port está disponible"
}

case $HADOOP_NODE_TYPE in
    namenode)
        echo "Iniciando NameNode..."
        if [ ! -f /hadoop/dfs/name/initialized ]; then
            hdfs namenode -format -force
            touch /hadoop/dfs/name/initialized
        fi
        hdfs namenode
        ;;

    resourcemanager)
        echo "Iniciando ResourceManager..."
        wait_for_service namenode 9870
        yarn resourcemanager
        ;;

    datanode)
        echo "Iniciando DataNode y NodeManager..."
        wait_for_service namenode 9870
        wait_for_service resourcemanager 8031
        hdfs datanode &
        yarn nodemanager
        ;;

    client)
        echo "Nodo cliente listo para ejecutar jobs..."
        wait_for_service namenode 9870
        wait_for_service resourcemanager 8031

        # Configurar AWS CLI para MinIO
        export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY:-minioadmin}
        export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY:-minioadmin123}
        export AWS_DEFAULT_REGION=us-east-1

        # También configurar con aws configure para persistencia
        aws configure set aws_access_key_id ${MINIO_ACCESS_KEY:-minioadmin}
        aws configure set aws_secret_access_key ${MINIO_SECRET_KEY:-minioadmin123}
        aws configure set default.region us-east-1

        echo "AWS CLI configurado para MinIO"
        tail -f /dev/null
        ;;

    *)
        echo "Tipo de nodo no reconocido: $HADOOP_NODE_TYPE"
        exit 1
        ;;
esac
