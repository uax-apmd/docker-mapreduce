# lee JSON por línea y emite "type\t1"
import sys, json
for line in sys.stdin:
    line=line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
        t = rec.get("type","unknown")
        print(f"{t}\t1")
    except Exception:
        # ignora líneas corruptas
        continue
