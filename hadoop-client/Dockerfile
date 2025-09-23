# hadoop-client/Dockerfile
FROM eclipse-temurin:8-jre-jammy

# Herramientas necesarias
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip \
    curl ca-certificates jq bash coreutils findutils \
 && rm -rf /var/lib/apt/lists/*

# Hadoop CLI 3.2.1 (sin daemons)
ENV HADOOP_VERSION=3.2.1
RUN curl -fsSL https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    -o /tmp/hadoop.tgz \
 && mkdir -p /opt \
 && tar -xzf /tmp/hadoop.tgz -C /opt \
 && mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop \
 && rm -f /tmp/hadoop.tgz

ENV HADOOP_HOME=/opt/hadoop
ENV PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"

# MinIO client (mc) para mirror S3 <-> local
RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc \
 && chmod +x /usr/local/bin/mc

WORKDIR /job
COPY mapper.py reducer.py run_job.sh ./
RUN chmod +x /job/run_job.sh
