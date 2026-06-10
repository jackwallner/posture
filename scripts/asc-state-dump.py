#!/usr/bin/env python3
"""One-off: dump current ASC app/version/build state for release readiness."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib as A

key_id, issuer_id, key_path = A.load_credentials()
client = A.ASCClient(A.bearer_token(key_id, issuer_id, key_path))

bundle = "com.jackwallner.posture"
app = A.find_app(client, bundle)
app_id = app["id"]
print(f"APP: {app['attributes'].get('name')}  id={app_id}  bundle={bundle}")

versions = A.list_versions(client, app_id)
print(f"\nVERSIONS ({len(versions)}):")
for v in versions:
    a = v["attributes"]
    vid = v["id"]
    # build linked?
    try:
        b = client.get(f"/appStoreVersions/{vid}/build")
        bd = b.get("data")
        build_str = bd["id"] if bd else None
    except Exception as e:
        build_str = f"err:{e}"
    print(f"  {a.get('versionString'):8} {a.get('appStoreState'):28} release={a.get('releaseType')}  buildLinked={bool(build_str) and 'err' not in str(build_str)}")

# latest builds + processing state
print("\nBUILDS (latest 5):")
builds = A.list_all(client, f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5")
for b in builds[:5]:
    a = b["attributes"]
    print(f"  v{a.get('version'):4} state={a.get('processingState'):12} expired={a.get('expired')} uploaded={a.get('uploadedDate')} minOS={a.get('minOsVersion')}")

# app-level info / live
live = A.find_live_version(client, app_id)
editable = A.find_editable_version(client, app_id)
print(f"\nLIVE: {live['attributes']['versionString']+' '+live['attributes']['appStoreState'] if live else 'NONE'}")
print(f"EDITABLE: {editable['attributes']['versionString']+' '+editable['attributes']['appStoreState'] if editable else 'NONE'}")
