#!/usr/bin/env python3
"""Put a build in front of an internal TestFlight tester, and prove it landed.

A build can be VALID, processed and export-compliant and still be invisible in
the TestFlight app, because none of that makes anyone a tester. Being the
Account Holder does not either: an internal tester is a betaTester record whose
email matches an App Store Connect user, sitting in an internal betaGroup that
the build is attached to. This script creates that chain and then reads every
link back from Apple.

Read-only unless --apply is passed. The report it prints without --apply is the
diagnosis: it names which of group / tester / build attachment is missing.

The key is a team key, so the JWT carries `iss`. Signing it as an individual
key (sub="user", no iss) returns a bare 401 that is indistinguishable from a
revoked key.
"""

import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

API = "https://api.appstoreconnect.apple.com"


def b64(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def token(key_pem: bytes, kid: str, issuer: str) -> str:
    header = {"alg": "ES256", "kid": kid, "typ": "JWT"}
    now = int(time.time())
    claims = {"iss": issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}

    signing_input = (
        f"{b64(json.dumps(header, separators=(',', ':')).encode())}."
        f"{b64(json.dumps(claims, separators=(',', ':')).encode())}".encode()
    )
    key = serialization.load_pem_private_key(key_pem, password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise SystemExit(f"{type(key).__name__} cannot sign ES256; expected EC P-256")
    r, s = utils.decode_dss_signature(key.sign(signing_input, ec.ECDSA(hashes.SHA256())))
    return (
        f"{signing_input.decode()}.{b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"
    )


def call(jwt: str, method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Authorization", f"Bearer {jwt}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else {"status": r.status}
    except urllib.error.HTTPError as e:
        # Keep the body. A 400 that names the offending attribute and a 409 that
        # says the resource already exists are different answers behind similar
        # codes, and only the body separates them.
        raise SystemExit(f"{method} {path} -> HTTP {e.code}\n{e.read().decode()[:800]}")


def survey(jwt: str, app: str) -> dict:
    """Everything the visibility of a build in TestFlight depends on."""
    builds = call(jwt, "GET", f"/v1/apps/{app}/builds?limit=5")["data"]
    groups = call(jwt, "GET", f"/v1/apps/{app}/betaGroups?limit=50")["data"]
    users = call(jwt, "GET", "/v1/users?limit=50")["data"]
    state = {"builds": [], "groups": [], "users": users}

    # The build -> group edge is only readable from the group side; Apple answers
    # GET /v1/builds/{id}/betaGroups with a 403 saying the relationship allows
    # CREATE and DELETE only. Reading it the other way and swallowing that 403
    # yields an empty list that looks exactly like "attached to nothing".
    for g in groups:
        state["groups"].append(
            {
                "id": g["id"],
                "name": g["attributes"]["name"],
                "isInternalGroup": g["attributes"]["isInternalGroup"],
                "hasAccessToAllBuilds": g["attributes"]["hasAccessToAllBuilds"],
                "buildIds": [
                    b["id"]
                    for b in call(jwt, "GET", f"/v1/betaGroups/{g['id']}/builds?limit=50")["data"]
                ],
                "testers": [
                    (t["attributes"]["email"], t["attributes"]["state"])
                    for t in call(jwt, "GET", f"/v1/betaGroups/{g['id']}/betaTesters")["data"]
                ],
            }
        )
    for b in builds:
        detail = call(jwt, "GET", f"/v1/builds/{b['id']}/buildBetaDetail")["data"]
        state["builds"].append(
            {
                "id": b["id"],
                "version": b["attributes"]["version"],
                "processingState": b["attributes"]["processingState"],
                "expired": b["attributes"]["expired"],
                "internalBuildState": detail["attributes"]["internalBuildState"],
                "groups": [g["name"] for g in state["groups"] if b["id"] in g["buildIds"]],
            }
        )
    return state


def report(state: dict) -> None:
    print("builds:")
    for b in state["builds"]:
        print(
            f"  {b['version']}  {b['processingState']}  {b['internalBuildState']}"
            f"  expired={b['expired']}  groups={b['groups'] or 'NONE'}"
        )
    print("beta groups:" if state["groups"] else "beta groups: NONE")
    for g in state["groups"]:
        kind = "internal" if g["isInternalGroup"] else "EXTERNAL"
        print(f"  {g['name']}  ({kind}, allBuilds={g['hasAccessToAllBuilds']})")
        for email, st in g["testers"] or []:
            print(f"    {email}  {st}")
        if not g["testers"]:
            print("    no testers")
    print("App Store Connect users:")
    for u in state["users"]:
        a = u["attributes"]
        print(f"  {a['username']}  {a['roles']}")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--key", required=True)
    p.add_argument("--kid", required=True)
    p.add_argument("--issuer", required=True)
    p.add_argument("--app", required=True, help="App Store Connect app id")
    p.add_argument("--group", default="Internal")
    p.add_argument(
        "--tester",
        help="Apple Account of an existing App Store Connect user; defaults to "
        "the account holder read from /v1/users",
    )
    p.add_argument("--apply", action="store_true", help="create the group and tester")
    a = p.parse_args()

    jwt = token(open(a.key, "rb").read(), a.kid, a.issuer)

    print("=== before ===")
    state = survey(jwt, a.app)
    report(state)

    if not a.apply:
        print("\nRead-only. Re-run with --apply to create the group and tester.")
        return 0

    group = next((g for g in state["groups"] if g["name"] == a.group), None)
    if group is None:
        print(f"\nPOST /v1/betaGroups  ({a.group}, internal)")
        call(
            jwt,
            "POST",
            "/v1/betaGroups",
            {
                "data": {
                    "type": "betaGroups",
                    "attributes": {
                        "name": a.group,
                        "isInternalGroup": True,
                        "hasAccessToAllBuilds": True,
                    },
                    "relationships": {"app": {"data": {"type": "apps", "id": a.app}}},
                }
            },
        )
        state = survey(jwt, a.app)
        group = next((g for g in state["groups"] if g["name"] == a.group), None)
        if group is None:
            raise SystemExit("the group is not there after a POST that did not error")
        if not group["isInternalGroup"]:
            # An external group would put the build in front of App Review
            # instead of the tester. Undo rather than leave it.
            call(jwt, "DELETE", f"/v1/betaGroups/{group['id']}")
            raise SystemExit(
                "Apple accepted the POST but created an EXTERNAL group; deleted it. "
                "Create the internal group in App Store Connect by hand and re-run."
            )
        print(f"created {group['id']} (internal)")
    else:
        print(f"\ngroup {a.group} already exists ({group['id']})")

    email = a.tester
    if not email:
        holder = next(
            (u for u in state["users"] if "ACCOUNT_HOLDER" in u["attributes"]["roles"]),
            None,
        )
        if holder is None:
            raise SystemExit("no account holder in /v1/users; pass --tester")
        email = holder["attributes"]["username"]
    name = next(
        (
            u["attributes"]
            for u in state["users"]
            if u["attributes"]["username"] == email
        ),
        None,
    )
    if name is None:
        raise SystemExit(
            f"{email} is not an App Store Connect user. An internal tester must be "
            "one: invite them under Users and Access first."
        )

    if email not in [t[0] for t in group["testers"]]:
        print(f"POST /v1/betaTesters  ({email} -> {a.group})")
        call(
            jwt,
            "POST",
            "/v1/betaTesters",
            {
                "data": {
                    "type": "betaTesters",
                    "attributes": {
                        "email": email,
                        "firstName": name["firstName"],
                        "lastName": name["lastName"],
                    },
                    "relationships": {
                        "betaGroups": {
                            "data": [{"type": "betaGroups", "id": group["id"]}]
                        }
                    },
                }
            },
        )
    else:
        print(f"{email} is already in {a.group}")

    live = next(b for b in survey(jwt, a.app)["builds"] if not b["expired"])
    if a.group not in live["groups"]:
        print(f"POST /v1/builds/{live['id']}/relationships/betaGroups")
        call(
            jwt,
            "POST",
            f"/v1/builds/{live['id']}/relationships/betaGroups",
            {"data": [{"type": "betaGroups", "id": group["id"]}]},
        )

    print("\n=== after ===")
    final = survey(jwt, a.app)
    report(final)

    # The success criterion, stated as one expression rather than inferred from
    # the absence of an error: a non-expired build attached to an internal group
    # that contains the tester.
    ok = any(
        b["processingState"] == "VALID"
        and not b["expired"]
        and any(
            g["name"] in b["groups"] and g["isInternalGroup"]
            and email in [t[0] for t in g["testers"]]
            for g in final["groups"]
        )
        for b in final["builds"]
    )
    print(f"\n{email} can install a VALID build: {ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
