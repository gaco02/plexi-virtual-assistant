#!/usr/bin/env python3
"""
Authenticated backend checks for strict Firebase-protected routes.

Usage:
  python backend/tests/auth_backend_checks.py --token <FIREBASE_ID_TOKEN>
  python backend/tests/auth_backend_checks.py --token <FIREBASE_ID_TOKEN> --base-url http://127.0.0.1:8000

If no token is provided, this script exits with guidance.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from typing import Any, Dict, Optional

import requests


@dataclass
class TestResult:
    name: str
    ok: bool
    status_code: Optional[int] = None
    detail: str = ""


def _pretty(data: Any) -> str:
    try:
        return json.dumps(data, indent=2, ensure_ascii=False)
    except Exception:
        return str(data)


def run_get(session: requests.Session, base_url: str, path: str, headers: Dict[str, str], timeout: int = 15) -> requests.Response:
    return session.get(f"{base_url}{path}", headers=headers, timeout=timeout)


def run_post(
    session: requests.Session,
    base_url: str,
    path: str,
    payload: Dict[str, Any],
    headers: Dict[str, str],
    timeout: int = 20,
) -> requests.Response:
    return session.post(f"{base_url}{path}", json=payload, headers=headers, timeout=timeout)


def check_test_token(session: requests.Session, base_url: str, headers: Dict[str, str]) -> TestResult:
    name = "GET /api/auth/test-token"
    try:
        resp = run_get(session, base_url, "/api/auth/test-token", headers)
        body = resp.json()
        ok = resp.status_code == 200 and body.get("message") == "Token valid"
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body))
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_preferences_get(session: requests.Session, base_url: str, headers: Dict[str, str]) -> TestResult:
    name = "GET /api/auth/preferences"
    try:
        resp = run_get(session, base_url, "/api/auth/preferences", headers)
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, dict)
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body))
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_preferences_post(session: requests.Session, base_url: str, headers: Dict[str, str]) -> TestResult:
    name = "POST /api/auth/preferences"
    payload = {
        "monthly_salary": 5000,
        "weight_goal": "maintain",
        "current_weight": 70,
        "target_weight": 70,
        "daily_calorie_target": 2200,
        "preferred_name": "Local Test User",
        "height": 175,
        "age": 30,
        "sex": "male",
    }
    try:
        resp = run_post(session, base_url, "/api/auth/preferences", payload, headers)
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, dict)
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body))
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_budget_summary(session: requests.Session, base_url: str, headers: Dict[str, str]) -> TestResult:
    name = "GET /budget/summary"
    try:
        resp = run_get(session, base_url, "/budget/summary", headers)
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, dict)
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body)[:500])
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def check_calories_summary(session: requests.Session, base_url: str, headers: Dict[str, str]) -> TestResult:
    name = "GET /calories/summary"
    try:
        resp = run_get(session, base_url, "/calories/summary", headers)
        body = resp.json()
        ok = resp.status_code == 200 and isinstance(body, dict)
        return TestResult(name=name, ok=ok, status_code=resp.status_code, detail=_pretty(body)[:500])
    except Exception as exc:
        return TestResult(name=name, ok=False, detail=str(exc))


def print_summary(results: list[TestResult]) -> int:
    print("\n=== Authenticated Backend Test Results ===")
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
    parser = argparse.ArgumentParser(description="Run authenticated checks against backend API")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000", help="Backend base URL")
    parser.add_argument("--token", default="", help="Firebase ID token")
    args = parser.parse_args()

    if not args.token:
        print("No token provided. Run with --token <FIREBASE_ID_TOKEN>")
        return 2

    headers = {
        "Authorization": f"Bearer {args.token}",
        "Content-Type": "application/json",
    }

    session = requests.Session()
    results = [
        check_test_token(session, args.base_url, headers),
        check_preferences_get(session, args.base_url, headers),
        check_preferences_post(session, args.base_url, headers),
        check_budget_summary(session, args.base_url, headers),
        check_calories_summary(session, args.base_url, headers),
    ]
    return print_summary(results)


if __name__ == "__main__":
    sys.exit(main())
