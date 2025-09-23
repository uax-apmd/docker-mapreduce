# webapp/app.py
import os, json, uuid
from datetime import datetime, timezone
from flask import Flask, request

import boto3
from botocore.client import Config

app = Flask(__name__, static_folder="static", static_url_path="/static")

S3_BUCKET = os.environ.get("S3_BUCKET_LOGS", "logs")
ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio:9000")
AWS_ACCESS_KEY_ID = os.environ["AWS_ACCESS_KEY_ID"]
AWS_SECRET_ACCESS_KEY = os.environ["AWS_SECRET_ACCESS_KEY"]
AWS_REGION = os.environ.get("AWS_REGION","us-east-1")

s3 = boto3.client(
    "s3",
    endpoint_url=ENDPOINT,
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION,
    config=Config(s3={"addressing_style": "path"})
)

def put_event(event: dict) -> str:
    # añade metadata común y sube como JSONL (1 línea por objeto)
    event = {
        **event,
        "ts": datetime.now(timezone.utc).isoformat(),
        "ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        "ua": request.headers.get("User-Agent"),
    }
    key = f"dt={datetime.utcnow().strftime('%Y-%m-%d')}/hour={datetime.utcnow().strftime('%H')}/{uuid.uuid4()}.json"
    s3.put_object(Bucket=S3_BUCKET, Key=key, Body=(json.dumps(event) + "\n").encode("utf-8"))
    return key

@app.route("/ui")
def ui():
    # sirve el cliente HTML
    return app.send_static_file("index.html")

@app.route("/api/log", methods=["POST"])
def api_log():
    data = request.get_json(silent=True) or {}
    event_type = (data.get("type") or "pageview").strip()
    path = (data.get("path") or "/").strip()
    key = put_event({"type": event_type, "path": path})
    return f"ok {key}\n", 200

# Compat: endpoint simple que loguea en GET (como ya tenías)
@app.route("/")
def index():
    key = put_event({
        "type": "pageview",
        "path": request.args.get("path", "/")
    })
    return f"ok {key}\n"

# Genera N eventos sintéticos
@app.route("/spam")
def spam():
    n = int(request.args.get("n","100"))
    for _ in range(n):
        put_event({"type": "click", "path": "/product"})
    return f"generated {n}\n"
