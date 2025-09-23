#!/usr/bin/env bash
set -euo pipefail

# ---- Entradas por entorno ----
ENDPOINT="${MINIO_ENDPOINT:-http://minio:9000}"
LOGS_BUCKET="${S3_BUCKET_LOGS:-logs}"
RESULTS_BUCKET="${S3_BUCKET_RESULTS:-results}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Dirección HDFS/YARN
HDFS_URI="${HDFS_NAMENODE_URI:-hdfs://namenode:8020}"
YARN_RM_HOST="${YARN_RM_HOST:-resourcemanager}"   # nombre del servicio en compose

export JAVA_HOME=${JAVA_HOME:-/opt/java/openjdk}
export HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"

CONF_DIR="$HADOOP_HOME/etc/hadoop"
mkdir -p "$CONF_DIR"

# ---- Genera configuraciones mínimas ----
cat > "$CONF_DIR/core-site.xml" <<EOF
<?xml version="1.0"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>${HDFS_URI}</value>
  </property>
</configuration>
EOF

cat > "$CONF_DIR/yarn-site.xml" <<EOF
<?xml version="1.0"?>
<configuration>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>${YARN_RM_HOST}</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
EOF

cat > "$CONF_DIR/mapred-site.xml" <<EOF
<?xml version="1.0"?>
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOF

# ---- Espera a HDFS respondiendo ----
echo "Esperando a HDFS en ${HDFS_URI}..."
until hdfs dfs -ls / >/dev/null 2>&1; do
  sleep 3
done
echo "HDFS listo."

# ---- MinIO alias ----
mc alias set minio "$ENDPOINT" "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"

# ---- Descarga logs S3 -> local ----
TMP_IN="/tmp/logs"
rm -rf "$TMP_IN" && mkdir -p "$TMP_IN"
echo "Mirroring s3://${LOGS_BUCKET} -> $TMP_IN ..."
mc mirror --overwrite "minio/${LOGS_BUCKET}" "$TMP_IN" || true

# ---- Sube a HDFS como JSONL (concat sencilla) ----
HDFS_IN="/input/logs_$(date +%s)"
hdfs dfs -mkdir -p "$HDFS_IN"
if find "$TMP_IN" -type f -name "*.json" | read; then
  find "$TMP_IN" -type f -name "*.json" -print0 \
    | xargs -0 -I{} sh -c 'cat "{}" >> "'$TMP_IN'/all.jsonl"'
  hdfs dfs -put -f "$TMP_IN/all.jsonl" "$HDFS_IN/"
else
  echo "No hay archivos .json en ${LOGS_BUCKET}. ¿Has generado eventos?"
  exit 0
fi

# ---- Localiza el jar de streaming ----
STREAMING_JAR=$(ls "$HADOOP_HOME"/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -n1)
OUT="/output/mapreduce_$(date +%s)"

echo "Lanzando Hadoop Streaming en YARN..."
yarn jar "$STREAMING_JAR" \
  -D mapreduce.job.name="poc-mapreduce-count-by-type" \
  -D mapreduce.job.reduces=2 \
  -files /job/mapper.py,/job/reducer.py \
  -mapper "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input "$HDFS_IN" \
  -output "$OUT"

# ---- Recoge resultados y sube a S3 ----
mkdir -p /results
hdfs dfs -get -f "$OUT/part-*" /results/
RES_FILE="/results/result_$(date +%s).txt"
cat /results/part-* > "$RES_FILE" && rm -f /results/part-*

mc cp "$RES_FILE" "minio/${RESULTS_BUCKET}/"
echo "Hecho. Resultado local: $RES_FILE"
