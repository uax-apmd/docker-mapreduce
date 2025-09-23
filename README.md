docker-mapreduce

Quickstart
- cp .env.example .env
- docker compose up -d
- Generate logs: curl "http://localhost:8080/spam?n=100"
- Run job: docker compose run --rm hadoop-client ./run_job.sh

UIs
- MinIO: http://localhost:9001 (console), S3 API: http://localhost:9000
- NameNode: http://localhost:9870
- YARN RM: http://localhost:8088
- JobHistory: http://localhost:8188
- Webapp: http://localhost:8080

Notes
- BDE Hadoop 3.2.1 images install Hadoop at /opt/hadoop-3.2.1. Classpaths are set accordingly in docker-compose.
- The client image uses HADOOP_HOME=/opt/hadoop and run_job.sh relies on $HADOOP_HOME to build classpaths.
