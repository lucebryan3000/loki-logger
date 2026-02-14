#!/usr/bin/env python3
import json, os, sys, time, socket, datetime, random
from datetime import timezone

OUT = os.environ.get("TELEMETRY_OUT", "/home/luce/_telemetry/telemetry.jsonl")
INTERVAL = float(os.environ.get("TELEMETRY_INTERVAL_SEC", "10"))
HOST = socket.gethostname()

def iso_utc():
    return datetime.datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')

def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "a", buffering=1, encoding="utf-8") as f:
        while True:
            evt = {
                "ts": iso_utc(),
                "kind": "telemetry",
                "source": "telemetry_writer",
                "host": HOST,
                "seq": int(time.time()),
                "value": random.randint(1, 100),
                "msg": "telemetry tick"
            }
            f.write(json.dumps(evt) + "\n")
            time.sleep(INTERVAL)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
