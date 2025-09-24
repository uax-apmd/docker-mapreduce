docker-mapreduce

Quickstart
- docker compose up -d
- Generate logs:
    - Execute: `curl "http://localhost:8080/spam?n=100"`
    - Vist: http://localhost:8080
- Run job: docker compose run --rm hadoop-client ./run_job.sh
- Recompile job: docker compose build hadoop-client
- Launch shell inside hadoop-client: docker compose run --rm hadoop-client bash
- Stop all: docker compose down

UIs
- MinIO: http://localhost:9001
- NameNode: http://localhost:9870
- YARN RM: http://localhost:8088
- Webapp: http://localhost:8080
