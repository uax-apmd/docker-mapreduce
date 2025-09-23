FROM bde2020/hadoop-nodemanager:2.0.0-hadoop3.2.1-java8
USER root
RUN set -eux; \
    sed -i 's|deb.debian.org|archive.debian.org|g; s|security.debian.org|archive.debian.org|g' /etc/apt/sources.list || true; \
    sed -i '/stretch-updates/d' /etc/apt/sources.list || true; \
    printf "Acquire::Check-Valid-Until \"false\";\n" > /etc/apt/apt.conf.d/99no-check-valid; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3 ca-certificates; \
    rm -rf /var/lib/apt/lists/*
RUN ln -sf /usr/bin/python3 /usr/local/bin/python3
USER root
