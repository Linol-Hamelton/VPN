#!/usr/bin/env python3
"""
Remove a VLESS client from an x-ui inbound (SQLite DB).

This script removes the client from:
  - inbounds.settings JSON (clients list)
  - client traffic/stats table (if present), so the UI doesn't keep showing it

It does not print any REALITY private keys.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import uuid as uuidlib
from typing import Any, Dict, List, Optional, Tuple


def _fail(msg: str, code: int = 2) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def _table_exists(cur: sqlite3.Cursor, name: str) -> bool:
    row = cur.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", (name,)
    ).fetchone()
    return bool(row)


def _cols(cur: sqlite3.Cursor, table: str) -> List[str]:
    return [r[1] for r in cur.execute(f"PRAGMA table_info({table})")]


def _table_info(cur: sqlite3.Cursor, table: str) -> List[Tuple[int, str, str, int, Optional[str], int]]:
    return list(cur.execute(f"PRAGMA table_info({table})"))


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
    try:
        return json.loads(s)
    except Exception as e:
        _fail(f"Failed to parse JSON from DB: {e}")
        raise


def _dump_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=True, separators=(",", ":"))


def _norm_uuid(s: str) -> str:
    try:
        return str(uuidlib.UUID(s))
    except Exception:
        return ""


def _find_traffic_table(cur: sqlite3.Cursor) -> Optional[str]:
    for t in ("client_traffics", "client_traffic", "clientStats", "client_stats"):
        if _table_exists(cur, t):
            return t
    return None


def _traffic_cols(cur: sqlite3.Cursor, table: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    info = _table_info(cur, table)
    cols = [c[1] for c in info]
    lut = {c.lower(): c for c in cols}

    email_col = None
    for k in ("email", "user", "username"):
        if k in lut:
            email_col = lut[k]
            break

    inbound_col = None
    for k in ("inbound_id", "inboundid", "inbound"):
        if k in lut:
            inbound_col = lut[k]
            break

    uuid_col = None
    for k in ("uuid", "client_id", "clientid", "xray_uuid", "xrayuuid"):
        if k in lut:
            uuid_col = lut[k]
            break

    return email_col, inbound_col, uuid_col


def main() -> None:
    ap = argparse.ArgumentParser(description="Remove VLESS client from x-ui inbound (SQLite).")
    ap.add_argument("--db", default="/etc/x-ui/x-ui.db", help="Path to x-ui SQLite db")
    ap.add_argument("--inbound-id", type=int, default=None)
    ap.add_argument("--inbound-port", type=int, default=None)
    ap.add_argument("--inbound-tag", default=None)
    ap.add_argument("--email", action="append", default=[], help="Client email to remove (repeatable)")
    ap.add_argument("--uuid", action="append", default=[], help="Client UUID to remove (repeatable)")
    ap.add_argument("--json", action="store_true", help="Print JSON output")
    ap.add_argument("--force", action="store_true", help="Do not error if client not found")
    args = ap.parse_args()

    if not os.path.exists(args.db):
        _fail(f"DB file not found: {args.db}")

    emails = [e.strip() for e in (args.email or []) if (e or "").strip()]
    uuids = [_norm_uuid(u.strip()) for u in (args.uuid or []) if (u or "").strip()]
    uuids = [u for u in uuids if u]

    if not emails and not uuids:
        _fail("Provide at least one --email or --uuid.")

    con = sqlite3.connect(args.db)
    cur = con.cursor()

    if not _table_exists(cur, "inbounds"):
        _fail("DB does not contain 'inbounds' table.")

    cols = _cols(cur, "inbounds")
    id_col = "id" if "id" in cols else None
    if not id_col:
        _fail(f"Can't find id column in inbounds. Columns: {cols}")

    settings_col = _pick_col(cols, ["settings", "setting"])
    if not settings_col:
        _fail(f"Can't find settings column in inbounds. Columns: {cols}")

    stream_col = _pick_col(cols, ["stream_settings", "streamSettings"])  # unused, but ok to keep consistent
    tag_col = "tag" if "tag" in cols else None
    port_col = "port" if "port" in cols else None

    where = None
    params: Tuple[Any, ...] = ()
    if args.inbound_id is not None:
        where = f"{id_col}=?"
        params = (args.inbound_id,)
    elif args.inbound_port is not None:
        if not port_col:
            _fail("inbounds table does not have 'port' column.")
        where = f"{port_col}=?"
        params = (args.inbound_port,)
    elif args.inbound_tag is not None:
        if not tag_col:
            _fail("inbounds table does not have 'tag' column.")
        where = f"{tag_col}=?"
        params = (args.inbound_tag,)
    else:
        _fail("Select inbound with --inbound-id OR --inbound-port OR --inbound-tag.")

    select_cols = [id_col]
    if port_col:
        select_cols.append(port_col)
    if tag_col:
        select_cols.append(tag_col)
    select_cols.append(settings_col)
    if stream_col:
        select_cols.append(stream_col)

    row = cur.execute(f"SELECT {','.join(select_cols)} FROM inbounds WHERE {where}", params).fetchone()
    if not row:
        _fail("Inbound not found.")

    idx = 0
    inbound_id = int(row[idx]); idx += 1
    inbound_port = int(row[idx]) if port_col else 0; idx += 1 if port_col else 0
    inbound_tag = str(row[idx]) if tag_col else ""; idx += 1 if tag_col else 0
    settings_raw = row[idx]; idx += 1

    settings = _load_json_maybe(settings_raw)
    clients = settings.get("clients")
    if clients is None:
        clients = []
        settings["clients"] = clients
    if not isinstance(clients, list):
        _fail("Inbound settings JSON has non-list 'clients' field; refusing to edit.")

    before = len(clients)
    removed: List[Dict[str, Any]] = []
    kept: List[Any] = []
    want_emails = set(emails)
    want_uuids = set(uuids)

    for c in clients:
        if not isinstance(c, dict):
            kept.append(c)
            continue
        e = str(c.get("email") or "")
        cid = _norm_uuid(str(c.get("id") or ""))
        match = (e in want_emails) or (cid and cid in want_uuids)
        if match:
            removed.append({"email": e, "id": cid, "flow": c.get("flow", "")})
        else:
            kept.append(c)

    if before == len(kept) and not args.force:
        _fail("No matching clients found in inbound settings.")

    settings["clients"] = kept
    cur.execute(
        f"UPDATE inbounds SET {settings_col}=? WHERE id=?",
        (_dump_json(settings), inbound_id),
    )

    traffic_table = _find_traffic_table(cur)
    traffic_deleted = 0
    traffic_info = ""
    if traffic_table:
        email_col, inbound_col, uuid_col = _traffic_cols(cur, traffic_table)
        if email_col and inbound_col:
            # delete by email/inbound and by uuid if available
            for e in want_emails:
                traffic_deleted += cur.execute(
                    f"DELETE FROM {traffic_table} WHERE {email_col}=? AND {inbound_col}=?",
                    (e, inbound_id),
                ).rowcount
            if uuid_col:
                for u in want_uuids:
                    traffic_deleted += cur.execute(
                        f"DELETE FROM {traffic_table} WHERE {uuid_col}=? AND {inbound_col}=?",
                        (u, inbound_id),
                    ).rowcount
            traffic_info = f"deleted from {traffic_table}"
        else:
            traffic_info = f"traffic table {traffic_table} missing inbound/email columns"

    con.commit()

    out = {
        "ok": True,
        "inbound": {"id": inbound_id, "port": inbound_port, "tag": inbound_tag},
        "requested": {"emails": emails, "uuids": uuids},
        "removed": removed,
        "clients_before": before,
        "clients_after": len(kept),
        "traffic": {"table": traffic_table or "", "deleted_rows": traffic_deleted, "info": traffic_info},
    }
    if args.json:
        print(json.dumps(out, ensure_ascii=True, indent=2))
    else:
        print(json.dumps(out, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()

