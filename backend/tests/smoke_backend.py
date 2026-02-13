#!/usr/bin/env python3
"""
Backend smoke tests for local/dev validation.

Usage:
  python backend/tests/smoke_backend.py
  python backend/tests/smoke_backend.py --base-url http://127.0.0.1:8000

This script focuses on endpoints that should work in local mode,
including fallback-auth paths when Firebase Admin is not configured.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import asyncio
from dataclasses import dataclass
from typing import Any, Dict, Optional

import requests
import asyncpg


@dataclass
class TestResult:
    name: str
    ok: bool
    status_code: Optional[int] = None
    detail: str = ""


async def _seed_dev_user_async() -> bool:
    db_host = os.getenv("DB_HOST", "127.0.0.1")
    db_user = os.getenv("DB_USER", "postgres")
    db_password = os.getenv("DB_PASSWORD", "postgres")
    db_name = os.getenv("DB_NAME", "postgres")
    db_port = int(os.getenv("DB_PORT", "5432"))

    if db_host.startswith("/cloudsql"):
        conn = await asyncpg.connect(
            user=db_user,
            password=db_password,
            database=db_name,
            host=db_host,
        )
    else:
        conn = await asyncpg.connect(
            user=db_user,
            password=db_password,
            database=db_name,
            host=db_host,
            port=db_port,
        )

    try:
        await conn.execute(
            """
            INSERT INTO users (email, firebase_uid, name, created_at)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
            ON CONFLICT (firebase_uid) DO NOTHING
            """,
            "dev@example.com",
            "dev-user",
            "Local Dev User",
        )
        return True
    finally:
        await conn.close()


def seed_dev_user() -> tuple[bool, str]:
    try:
        ok = asyncio.run(_seed_dev_user_async())
        return ok, "seeded/verified dev-user"
    except Exception as exc:
        return False, f"unable to seed dev-user ({exc})"


def _pretty(data: Any) -> str:
    try:
        return json.dumps(data, indent=2, ensure_ascii=False)
    except Exception:
        return str(data)


def run_get(session: requests.Session, base_url: str, path: str, timeout: int = 12) -> requests.Response:
    return session.get(f"{base_url}{path}", timeout=timeout)


def run_post(
    session: requests.Session,
    base_url: str,
    path: str,
    payload: Dict[str, Any],
    timeout: int = 20,
) -> requests.Response:
    return session.post(f"{base_url}{path}", json=payload, timeout=timeout)


def check_health(session: requests.Session, base_url: str) -> TestResult:
    name = "GET /health"
    try:
        resp = run_get(session, base_url, "/health")
        body = resp.json()
        ok = resp.status_code == 200 and body.get("status") == "healthy"
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body))
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_root(session: requests.Session, base_url: str) -> TestResult:
    name = "GET /"
    try:
        resp = run_get(session, base_url, "/")
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, dict)
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body))
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_restaurants(session: requests.Session, base_url: str) -> TestResult:
    name = "GET /restaurants"
    try:
        resp = run_get(session, base_url, "/restaurants")
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, list)
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=f"items={len(body)}")
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_daily_recommendations(session: requests.Session, base_url: str) -> TestResult:
    name = "GET /restaurants/daily"
    try:
        resp = run_get(session, base_url, "/restaurants/daily")
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, list)
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=f"items={len(body)}")
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_chat(session: requests.Session, base_url: str) -> TestResult:
    name = "POST /chat/"
    payload = {
        "message": "How much did I spend today?",
        "conversation_history": [],
        "tool": None,
        "conversation_id": None,
    }
    try:
        resp = run_post(session, base_url, "/chat/", payload)
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, dict) and "response" in body
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body)[:800])
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def print_summary(results: list[TestResult]) -> int:
    print("\n=== Backend Smoke Test Results ===")
    for result in results:
        mark = "✅" if result.ok else "❌"
        code = f" [{result.status_code}]" if result.status_code is not None else ""
        print(f"{mark} {result.name}{code}")
        if result.detail:
            print(f"    {result.detail}")

    passed = sum(1 for r in results if r.ok)
    total = len(results)
    print(f"\nPassed {passed}/{total} tests")
    return 0 if passed == total else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Run smoke tests against backend API")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000", help="Backend base URL")
    parser.add_argument(
        "--skip-seed-dev-user",
        action="store_true",
        help="Skip local DB seed step for fallback auth dev-user",
    )
    args = parser.parse_args()

    session = requests.Session()
    results: list[TestResult] = []

    if not args.skip_seed_dev_user:
        seeded, detail = seed_dev_user()
        results.append(
            TestResult(
                name="Seed local dev-user",
                ok=seeded,
                detail=detail,
            )
        )

    results.extend([
        check_health(session, args.base_url),
        check_root(session, args.base_url),
        check_restaurants(session, args.base_url),
        check_daily_recommendations(session, args.base_url),
        check_chat(session, args.base_url),
    ])
    return print_summary(results)


if __name__ == "__main__":
    sys.exit(main())
