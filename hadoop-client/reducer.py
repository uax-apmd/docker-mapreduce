# suma por clave
import sys
cur_key = None
acc = 0
for line in sys.stdin:
    key, val = line.strip().split("\t")
    val = int(val)
    if cur_key is None:
        cur_key = key
        acc = val
    elif key == cur_key:
        acc += val
    else:
        sys.stdout.write("{}\t{}\n".format(cur_key, acc))
        cur_key = key
        acc = val
if cur_key is not None:
    sys.stdout.write("{}\t{}\n".format(cur_key, acc))
