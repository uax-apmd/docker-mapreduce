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
    <name>yarn.resourcemanager.address</name>
    <value>${YARN_RM_HOST}:8032</value>
  </property>
  <property>
    <name>yarn.resourcemanager.scheduler.address</name>
    <value>${YARN_RM_HOST}:8030</value>
  </property>
  <property>
    <name>yarn.resourcemanager.resource-tracker.address</name>
    <value>${YARN_RM_HOST}:8031</value>
  </property>
  <property>
    <name>yarn.resourcemanager.webapp.address</name>
    <value>${YARN_RM_HOST}:8088</value>
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

# Si mc crea una carpeta con el nombre del bucket, úsala como raíz
SRC_DIR="$TMP_IN"
[ -d "$TMP_IN/$LOGS_BUCKET" ] && SRC_DIR="$TMP_IN/$LOGS_BUCKET"

echo "Listando ejemplo de archivos descargados:"
find "$SRC_DIR" -maxdepth 3 -type f -printf "%P\n" | head -n 10 || true

# Busca .json y .jsonl (profundidad arbitraria)
mapfile -t INPUT_FILES < <(find "$SRC_DIR" -type f \( -name "*.json" -o -name "*.jsonl" \))

if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
  echo "No hay archivos .json/.jsonl en ${LOGS_BUCKET}. ¿Has generado eventos?"
  exit 0
fi

echo "Encontrados ${#INPUT_FILES[@]} ficheros de entrada."

# ---- Sube a HDFS manteniendo múltiples ficheros (mejores splits) ----
HDFS_IN="/input/logs_$(date +%s)"
hdfs dfs -mkdir -p "$HDFS_IN"

# Sube en lotes para evitar problemas con ARG_MAX
printf '%s\0' "${INPUT_FILES[@]}" \
| xargs -0 -r -n 50 sh -c 'dest="$1"; shift; hdfs dfs -put -f "$@" "$dest"' _ "$HDFS_IN/"

# ---- Localiza el jar de streaming ----
STREAMING_JAR=$(ls "$HADOOP_HOME"/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -n1)
OUT="/output/mapreduce_$(date +%s)"

APP_CLASSPATH="/opt/hadoop-3.2.1/etc/hadoop:\
/opt/hadoop-3.2.1/share/hadoop/common/*:/opt/hadoop-3.2.1/share/hadoop/common/lib/*:\
/opt/hadoop-3.2.1/share/hadoop/hdfs/*:/opt/hadoop-3.2.1/share/hadoop/hdfs/lib/*:\
/opt/hadoop-3.2.1/share/hadoop/mapreduce/*:/opt/hadoop-3.2.1/share/hadoop/mapreduce/lib/*:\
/opt/hadoop-3.2.1/share/hadoop/yarn/*:/opt/hadoop-3.2.1/share/hadoop/yarn/lib/*"

yarn jar "$STREAMING_JAR" \
  -D mapreduce.framework.name=yarn \
  -D mapreduce.application.classpath="$APP_CLASSPATH" \
  -D yarn.app.mapreduce.am.env=HADOOP_HOME=/opt/hadoop-3.2.1,HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1 \
  -D mapreduce.map.env=HADOOP_HOME=/opt/hadoop-3.2.1,HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1 \
  -D mapreduce.reduce.env=HADOOP_HOME=/opt/hadoop-3.2.1,HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1 \
  -D yarn.app.mapreduce.am.resource.mb=256 \
  -D yarn.app.mapreduce.am.command-opts=-Xmx192m \
  -D mapreduce.map.memory.mb=256 \
  -D mapreduce.reduce.memory.mb=256 \
  -D mapreduce.map.java.opts=-Xmx192m \
  -D mapreduce.reduce.java.opts=-Xmx192m \
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
