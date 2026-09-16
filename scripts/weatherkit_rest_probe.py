#!/usr/bin/env python3
"""Ask weatherkit.apple.com for data over the REST path, as a control on the
device path's bare 401.

Same service, different credential: a JWT we sign with a key from the portal,
rather than the token the device mints from its provisioning profile. So the two
outcomes separate two hypotheses that a device run alone cannot:

  200 -> WeatherKit is provisioned and serving this team; the fault is confined
         to device-side token issuance.
  401 -> the service refuses this team through every door, which is a much
         stronger support ticket and clears the app, the Mac and the phone.

A 401 here is only meaningful if the key really is a WeatherKit key and the
Service ID really is registered. A wrong key returns exactly the same 401 as a
broken service, so confirm both in the portal before reading anything into it.
"""

import argparse, base64, json, sys, time, urllib.error, urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils


def b64(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def developer_token(key_pem: bytes, kid: str, team: str, sub: str) -> str:
    # Header and claims exactly as the WeatherKit REST docs specify; the docs
    # say to include only these, and extra claims are rejected.
    header = {"alg": "ES256", "kid": kid, "id": f"{team}.{sub}"}
    now = int(time.time())
    claims = {"iss": team, "iat": now, "exp": now + 900, "sub": sub}

    signing_input = (
        f"{b64(json.dumps(header, separators=(',', ':')).encode())}."
        f"{b64(json.dumps(claims, separators=(',', ':')).encode())}".encode()
    )

    key = serialization.load_pem_private_key(key_pem, password=None)
    # Not merely to satisfy the type checker: a .p8 that is not P-256 cannot
    # sign ES256 at all, and saying so here beats returning a 401 that would be
    # indistinguishable from the bug under investigation.
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise SystemExit(f"{type(key).__name__} cannot sign ES256; expected EC P-256")
    r, s = utils.decode_dss_signature(
        key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    )
    # JWS wants raw r||s, 32 bytes each — not the DER blob sign() returns.
    return (
        f"{signing_input.decode()}.{b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"
    )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--key", required=True, help="path to the AuthKey_*.p8")
    p.add_argument("--kid", required=True, help="10-char key id")
    p.add_argument("--team", default="877MLS29T9")
    p.add_argument("--sub", required=True, help="registered Service ID")
    p.add_argument("--lat", default="47.1397")  # Boston Harbor, the fixture site
    p.add_argument("--lon", default="-122.9055")
    a = p.parse_args()

    token = developer_token(open(a.key, "rb").read(), a.kid, a.team, a.sub)
    url = f"https://weatherkit.apple.com/api/v1/availability/{a.lat}/{a.lon}?country=US"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})

    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            print(f"HTTP {r.status}")
            print(r.read().decode()[:600])
            return 0
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:600]
        print(f"HTTP {e.code}")
        print(f"body: {body!r}" if body else "body: (empty)")
        # The device path returns 401 with Content-Length 0. Say whether this
        # matches that shape, since an identical answer is the whole finding.
        if e.code == 401:
            print(
                "\nSame status as the device path."
                if not body
                else "\n401, but with a body the device path did not return."
            )
        return 1
    except Exception as e:  # network, DNS, TLS
        print(f"request failed before Apple answered: {e}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
