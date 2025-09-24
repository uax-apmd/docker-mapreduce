import sys, json
for line in sys.stdin:
    line=line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
        t = rec.get("type","unknown")
        sys.stdout.write("{}\t1\n".format(t))
    except Exception:
        continue
