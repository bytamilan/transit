#!/usr/bin/env python3
"""Mints a short-lived Supabase service_role JWT signed with JWT_SECRET, for
local dev/admin scripts only (see create_demo_admin.sh). Self-hosted
Supabase has no fixed service-role key — GOTRUE_JWT_ADMIN_ROLES=service_role
in deploy/compose/compose.yaml means any JWT with role=service_role signed
by the same JWT_SECRET is treated as an admin token.
"""
import base64
import hashlib
import hmac
import json
import os
import time


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def main() -> None:
    secret = os.environ["JWT_SECRET"]
    header = {"alg": "HS256", "typ": "JWT"}
    now = int(time.time())
    payload = {"role": "service_role", "iss": "supabase-local", "iat": now, "exp": now + 3600}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"
    signature = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
    print(f"{signing_input}.{b64url(signature)}")


if __name__ == "__main__":
    main()
