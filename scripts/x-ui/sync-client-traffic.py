#!/usr/bin/env python3
"""
Backfill client traffic/stats rows for existing clients in an inbound.

Useful when clients were added by editing inbounds.settings directly and the UI
doesn't show them because it depends on a traffic table.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from typing import Any, Dict, List, Optional, Tuple


def _fail(msg: str, code: int = 2) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def _table_exists(cur: sqlite3.Cursor, name: str) -> bool:
    row = cur.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", (name,)
    ).fetchone()
    return bool(row)


def _table_info(cur: sqlite3.Cursor, table: str) -> List[Tuple[int, str, str, int, Optional[str], int]]:
    return list(cur.execute(f"PRAGMA table_info({table})"))


def _cols(cur: sqlite3.Cursor, table: str) -> List[str]:
    return [r[1] for r in cur.execute(f"PRAGMA table_info({table})")]


def _pick_col(cols: List[str], candidates: List[str]) -> Optional[str]:
    for c in candidates:
        if c in cols:
            return c
    return None


def _load_json_maybe(s: Optional[str]) -> Dict[str, Any]:
    if not s:
        return {}
    s = s.strip()
    if not s:
        return {}
    return json.loads(s)


def _ensure_client_traffic_row(
    cur: sqlite3.Cursor,
    *,
    inbound_id: int,
    email: str,
    client_uuid: str,
) -> Tuple[bool, str]:
    candidates = ["client_traffics", "client_traffic", "clientStats", "client_stats"]
    table = next((t for t in candidates if _table_exists(cur, t)), None)
    if not table:
        return False, "no client traffic table"

    info = _table_info(cur, table)
    cols = [c[1] for c in info]
    col_lut = {c.lower(): c for c in cols}

    email_col = None
    for k in ("email", "user", "username"):
        if k in col_lut:
            email_col = col_lut[k]
            break

    inbound_col = None
    for k in ("inbound_id", "inboundid", "inbound"):
        if k in col_lut:
            inbound_col = col_lut[k]
            break

    if not email_col or not inbound_col:
        return False, f"traffic table '{table}' missing inbound/email columns"

    row = cur.execute(
        f"SELECT 1 FROM {table} WHERE {email_col}=? AND {inbound_col}=? LIMIT 1",
        (email, inbound_id),
    ).fetchone()
    if row:
        return False, "traffic row already exists"

    payload: Dict[str, Any] = {email_col: email, inbound_col: inbound_id}

    for key in ("enable", "enabled", "active"):
        if key in col_lut:
            payload[col_lut[key]] = 1
            break

    for key in ("up", "uplink", "upload"):
        if key in col_lut:
            payload[col_lut[key]] = 0
            break
    for key in ("down", "downlink", "download"):
        if key in col_lut:
            payload[col_lut[key]] = 0
            break
    if "total" in col_lut:
        payload[col_lut["total"]] = 0

    for key in ("uuid", "client_id", "clientid", "xray_uuid", "xrayuuid"):
        if key in col_lut:
            payload[col_lut[key]] = client_uuid
            break

    for _cid, name, typ, notnull, dflt_value, pk in info:
        if pk == 1:
            continue
        if name in payload:
            continue
        if notnull == 1 and dflt_value is None:
            t = (typ or "").upper()
            if "INT" in t or "REAL" in t or "NUM" in t:
                payload[name] = 0
            else:
                payload[name] = ""

    cols_sql = ",".join(payload.keys())
    qs = ",".join(["?"] * len(payload))
    cur.execute(f"INSERT INTO {table} ({cols_sql}) VALUES ({qs})", tuple(payload.values()))
    return True, f"inserted traffic row into {table}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="/etc/x-ui/x-ui.db")
    ap.add_argument("--inbound-port", type=int, required=True)
    args = ap.parse_args()

    if not os.path.exists(args.db):
        _fail(f"DB file not found: {args.db}")

    con = sqlite3.connect(args.db)
    cur = con.cursor()

    if not _table_exists(cur, "inbounds"):
        _fail("DB does not contain 'inbounds' table.")

    cols = _cols(cur, "inbounds")
    settings_col = _pick_col(cols, ["settings", "setting"])
    if not settings_col:
        _fail(f"Can't find settings column in inbounds. Columns: {cols}")

    row = cur.execute(
        f"SELECT id,{settings_col} FROM inbounds WHERE port=?", (args.inbound_port,)
    ).fetchone()
    if not row:
        _fail("Inbound not found.")

    inbound_id = int(row[0])
    settings = _load_json_maybe(row[1])
    clients = settings.get("clients") or []
    if not isinstance(clients, list):
        _fail("Inbound settings 'clients' is not a list.")

    changed = 0
    skipped = 0
    errors: List[str] = []

    for c in clients:
        if not isinstance(c, dict):
            skipped += 1
            continue
        email = str(c.get("email") or "").strip()
        cid = str(c.get("id") or "").strip()
        if not email or not cid:
            skipped += 1
            continue
        try:
            ch, _msg = _ensure_client_traffic_row(cur, inbound_id=inbound_id, email=email, client_uuid=cid)
            if ch:
                changed += 1
            else:
                skipped += 1
        except Exception as e:
            errors.append(f"{email}: {e}")

    con.commit()
    out = {"ok": True, "inbound_id": inbound_id, "changed": changed, "skipped": skipped, "errors": errors}
    print(json.dumps(out, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()

