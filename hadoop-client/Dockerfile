# hadoop-client/Dockerfile
FROM eclipse-temurin:8-jre-jammy

# Herramientas necesarias
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip \
    curl ca-certificates jq bash coreutils findutils \
 && rm -rf /var/lib/apt/lists/*

# Hadoop CLI 3.2.1 (sin daemons)
ARG HADOOP_VERSION=3.2.1
# Si el tar.gz está en el contexto, lo usamos y evitamos red DESCARGA
COPY hadoop-${HADOOP_VERSION}.tar.gz /tmp/hadoop.tgz

# Fallbacks + reintentos si no está el archivo local
RUN set -eux; \
  if [ ! -s /tmp/hadoop.tgz ]; then \
    for u in \
      https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
      https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    ; do \
      echo "Trying $u"; \
      curl -fL --retry 5 --retry-connrefused \
           --speed-time 30 --speed-limit 100000 \
           -o /tmp/hadoop.tgz "$u" && break || true; \
    done; \
    test -s /tmp/hadoop.tgz; \
  fi; \
  mkdir -p /opt && tar -xzf /tmp/hadoop.tgz -C /opt && \
  mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && rm -f /tmp/hadoop.tgz

ENV HADOOP_HOME=/opt/hadoop
ENV PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"

# MinIO client (mc) para mirror S3 <-> local
RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc \
 && chmod +x /usr/local/bin/mc

WORKDIR /job
COPY mapper.py reducer.py run_job.sh ./
RUN chmod +x /job/run_job.sh
