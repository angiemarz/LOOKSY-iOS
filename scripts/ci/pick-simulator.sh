#!/usr/bin/env bash
# Prints the UDID of an available iPhone simulator on the newest iOS runtime.
set -euo pipefail
xcrun simctl list devices available --json | python3 -c '
import json, sys, re
data = json.load(sys.stdin)["devices"]
def version(runtime):
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
runtimes = sorted((r for r in data if "iOS" in r), key=version, reverse=True)
for runtime in runtimes:
    phones = [d for d in data[runtime] if d.get("isAvailable") and d["name"].startswith("iPhone")]
    if phones:
        preferred = [d for d in phones if re.match(r"iPhone \d+$", d["name"])] or phones
        device = preferred[-1]
        name = device["name"]
        print(device["udid"])
        print("Using " + name + " (" + runtime + ")", file=sys.stderr)
        sys.exit(0)
sys.exit("No iPhone simulator available")
'
