#!/usr/bin/env python3
"""Build the web demo's static site payload from WDFW's live ArcGIS service.

Run on demand, commit the result. The demo must not fetch WDFW at page load:
CORS, latency and WDFW uptime are three ways for a first impression to fail.

    python3 scripts/build_web_data.py          # -> site/data/sites.json
"""
import json, os, re, time, unicodedata, urllib.parse, urllib.request

BASE = ("https://geodataservices.wdfw.wa.gov/arcgis/rest/services"
        "/FP_Projects/MajorFishingArea/MapServer")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "site", "data", "sites.json")

# LaunchType's coded domain, read off the layer metadata rather than guessed.
LAUNCH = {1: "Concrete", 2: "Gravel", 3: "Hand launch", 4: "Unimproved"}


def query(layer, fields, where="1=1"):
    """Page through a layer. The service caps one response and flags the cap
    with exceededTransferLimit — trusting a single call silently truncates."""
    out, offset = [], 0
    while True:
        q = urllib.parse.urlencode({
            "where": where, "outFields": fields, "returnGeometry": "true",
            "outSR": "4326", "f": "json",
            "resultOffset": offset, "resultRecordCount": 1000,
        })
        with urllib.request.urlopen(f"{BASE}/{layer}/query?{q}", timeout=60) as r:
            d = json.load(r)
        feats = d.get("features", [])
        out += feats
        if not d.get("exceededTransferLimit") or not feats:
            return out
        offset += len(feats)
        time.sleep(0.3)


_seen = {}


def slug(s):
    v = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    v = re.sub(r"[^a-z0-9]+", "-", v.lower()).strip("-") or "site"
    n = _seen.get(v, 0)
    _seen[v] = n + 1
    return v if not n else f"{v}-{n + 1}"


def main():
    sites = []

    for f in query(0, "FacilityName,CountyName,Launch,LaunchType,Restrooms,"
                      "Camping,ADARestroom,ADABoatLaunch,PublicNotes"):
        a, g = f["attributes"], f.get("geometry") or {}
        if g.get("x") is None:
            continue
        sites.append({
            "id": slug(a.get("FacilityName")), "name": (a.get("FacilityName") or "").strip(),
            "lat": round(g["y"], 5), "lon": round(g["x"], 5),
            "county": a.get("CountyName"),
            "launch": LAUNCH.get(a.get("LaunchType")) if a.get("Launch") else None,
            "restrooms": bool(a.get("Restrooms")), "camping": bool(a.get("Camping")),
            "ada": bool(a.get("ADARestroom") or a.get("ADABoatLaunch")),
            "kind": "access",
        })

    for f in query(1, "*"):
        a, g = f["attributes"], f.get("geometry") or {}
        if g.get("x") is None:
            continue
        name = (a.get("GeoWeb.dbo.Fish_MapsPiers_V.PierName") or "").strip()
        sites.append({
            "id": slug(name), "name": name,
            "lat": round(g["y"], 5), "lon": round(g["x"], 5),
            "county": a.get("GeoWeb.dbo.Fish_MapsPiers_V.CountyFIPSName"),
            "launch": None, "restrooms": False, "camping": False, "ada": False,
            "kind": "pier",
        })

    counts = {k: sum(1 for s in sites if s["kind"] == k) for k in ("access", "pier")}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump({"source": "WDFW MajorFishingArea MapServer, layers 0 and 1",
                   "built": time.strftime("%Y-%m-%d"),
                   "counts": counts, "sites": sites}, fh, separators=(",", ":"))
    print(f"wrote {OUT}: {counts['access']} access sites, {counts['pier']} piers, "
          f"{os.path.getsize(OUT) // 1024} KB")
    # The app claims 477 access sites. A silent drop here would put a smaller
    # number on a public page than the one the resume and listing carry.
    if counts["access"] < 477:
        print(f"*** access sites {counts['access']} < 477 — paging or a filter changed ***")


if __name__ == "__main__":
    main()
