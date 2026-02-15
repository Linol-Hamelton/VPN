#!/usr/bin/env python3
"""
Add a VLESS client into an existing x-ui inbound (SQLite DB).

Goal: automate "create user" for VLESS+REALITY setups where x-ui forks differ.
This script:
  - updates inbounds.settings JSON to append a new client (id/email/flow)
  - optionally builds a vless:// share link (requires deriving pbk from REALITY privateKey)

It intentionally avoids printing REALITY privateKey.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import uuid as uuidlib
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import parse_qs, urlparse


def _fail(msg: str, code: int = 2) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


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
    # Keep ASCII for portability, compact for DB storage.
    return json.dumps(obj, ensure_ascii=True, separators=(",", ":"))


def _table_exists(cur: sqlite3.Cursor, name: str) -> bool:
    row = cur.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", (name,)
    ).fetchone()
    return bool(row)


def _cols(cur: sqlite3.Cursor, table: str) -> List[str]:
    return [r[1] for r in cur.execute(f"PRAGMA table_info({table})")]

def _table_info(cur: sqlite3.Cursor, table: str) -> List[Tuple[int, str, str, int, Optional[str], int]]:
    # (cid, name, type, notnull, dflt_value, pk)
    return list(cur.execute(f"PRAGMA table_info({table})"))


def _pick_col(cols: List[str], candidates: List[str]) -> Optional[str]:
    for c in candidates:
        if c in cols:
            return c
    return None


def _find_xray_bin() -> Optional[str]:
    candidates = [
        "/usr/local/x-ui/bin/xray-linux-amd64",
        "/usr/local/x-ui/bin/xray",
        "/usr/local/bin/xray",
        "/usr/bin/xray",
        "xray",
    ]
    for c in candidates:
        if c == "xray":
            # PATH lookup
            if any(os.access(os.path.join(p, "xray"), os.X_OK) for p in os.getenv("PATH", "").split(os.pathsep) if p):
                return "xray"
            continue
        if os.path.exists(c) and os.access(c, os.X_OK):
            return c
    return None


def _derive_reality_public_key(private_key_b64: str) -> Optional[str]:
    """
    Derive REALITY public key (pbk) from privateKey.

    Uses xray's built-in x25519 helper if available.
    Many builds support: `xray x25519 -i <privateKey>`
    """
    xray = _find_xray_bin()
    if not xray:
        return None

    # Try common flag spellings.
    cmd_variants = [
        [xray, "x25519", "-i", private_key_b64],
        [xray, "x25519", "--input", private_key_b64],
        [xray, "x25519", "-privateKey", private_key_b64],
    ]
    for cmd in cmd_variants:
        try:
            p = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=3)
        except Exception:
            continue
        out = (p.stdout or "") + "\n" + (p.stderr or "")
        m = re.search(r"Public key:\\s*([A-Za-z0-9+/=\\-_]{20,})", out, re.IGNORECASE)
        if p.returncode == 0 and m:
            return m.group(1).strip()
    return None


def _pick_first_nonempty(items: Any) -> Optional[str]:
    if not isinstance(items, list):
        return None
    for x in items:
        if isinstance(x, str) and x.strip():
            return x.strip()
    return None


def _ensure_client_traffic_row(
    cur: sqlite3.Cursor,
    *,
    inbound_id: int,
    email: str,
    client_uuid: str,
) -> Tuple[bool, str]:
    """
    Some x-ui/3x-ui forks display clients based on a traffic/stats table, not only inbound.settings.
    This tries to insert a minimal row into a known traffic table, if present.

    Returns (changed, message).
    """
    # Common table names across forks.
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

    # If already exists, nothing to do.
    row = cur.execute(
        f"SELECT 1 FROM {table} WHERE {email_col}=? AND {inbound_col}=? LIMIT 1",
        (email, inbound_id),
    ).fetchone()
    if row:
        return False, "traffic row already exists"

    # Build insert payload: set known keys; satisfy NOT NULL cols without defaults.
    payload: Dict[str, Any] = {email_col: email, inbound_col: inbound_id}

    # Optional columns we can fill if present.
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
    for key in ("total",):
        if key in col_lut:
            payload[col_lut[key]] = 0
            break
    for key in ("reset", "reset_time", "resettime"):
        if key in col_lut:
            payload[col_lut[key]] = 0
            break

    # If there is a UUID/client-id column, set it.
    for key in ("uuid", "client_id", "clientid", "xray_uuid", "xrayuuid"):
        if key in col_lut:
            payload[col_lut[key]] = client_uuid
            break

    # Satisfy remaining NOT NULL columns without defaults (skip PK).
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


def _vless_link(
    server: str,
    port: int,
    client_id: str,
    label: str,
    flow: str,
    sni: str,
    sid: str,
    pbk: str,
    fp: str,
    typ: str,
) -> str:
    # Keep it simple; most clients accept this form.
    # URL fragment is display-only; replace spaces with %20.
    frag = re.sub(r"\\s+", "%20", label.strip()) if label.strip() else "x-ui"
    return (
        f"vless://{client_id}@{server}:{port}"
        f"?encryption=none"
        f"&flow={flow}"
        f"&security=reality"
        f"&sni={sni}"
        f"&fp={fp}"
        f"&pbk={pbk}"
        f"&sid={sid}"
        f"&type={typ}"
        f"#{frag}"
    )

def _parse_template_vless(link: str) -> Dict[str, Any]:
    """
    Parse a vless:// share link and extract fields useful for REALITY.

    We intentionally only use non-secret fields (pbk/sni/sid/fp/type/flow/server/port).
    """
    link = (link or "").strip()
    if not link:
        return {}
    u = urlparse(link)
    if u.scheme.lower() != "vless":
        _fail("template vless link must start with vless://")

    # netloc: "<uuid>@host:port" (port optional)
    host = ""
    port = None
    if "@" in (u.netloc or ""):
        _user, _at, hostport = u.netloc.rpartition("@")
    else:
        hostport = u.netloc or ""
    # Split host:port (IPv6 in [] is not expected here, but handle minimally)
    if hostport.startswith("[") and "]" in hostport:
        # [IPv6]:port
        h = hostport.split("]", 1)[0].lstrip("[")
        rest = hostport.split("]", 1)[1]
        host = h
        if rest.startswith(":"):
            try:
                port = int(rest[1:])
            except Exception:
                port = None
    else:
        if ":" in hostport:
            h, p = hostport.rsplit(":", 1)
            host = h
            try:
                port = int(p)
            except Exception:
                port = None
        else:
            host = hostport

    q = parse_qs(u.query, keep_blank_values=True)
    # query values come as lists
    def q1(key: str) -> str:
        v = q.get(key)
        if not v:
            return ""
        return str(v[0] or "").strip()

    out: Dict[str, Any] = {}
    if host:
        out["server"] = host
    if port is not None:
        out["port"] = port
    for k in ("pbk", "sni", "sid", "fp", "type", "flow", "security"):
        v = q1(k)
        if v:
            out[k] = v
    return out


@dataclass
class Inbound:
    id: int
    port: int
    tag: str
    settings: Dict[str, Any]
    stream: Dict[str, Any]


def _load_inbound(
    cur: sqlite3.Cursor,
    *,
    inbound_id: Optional[int],
    inbound_port: Optional[int],
    inbound_tag: Optional[str],
) -> Tuple[Inbound, str, Optional[str]]:
    cols = _cols(cur, "inbounds")
    settings_col = _pick_col(cols, ["settings", "setting"])
    if not settings_col:
        _fail(f"Can't find settings column in inbounds. Columns: {cols}")

    stream_col = _pick_col(cols, ["stream_settings", "streamSettings"])
    tag_col = "tag" if "tag" in cols else None
    port_col = "port" if "port" in cols else None
    id_col = "id" if "id" in cols else None
    if not id_col:
        _fail(f"Can't find id column in inbounds. Columns: {cols}")

    where = None
    params: Tuple[Any, ...] = ()
    if inbound_id is not None:
        where = f"{id_col}=?"
        params = (inbound_id,)
    elif inbound_port is not None:
        if not port_col:
            _fail(f"inbounds table does not have a port column. Columns: {cols}")
        where = f"{port_col}=?"
        params = (inbound_port,)
    elif inbound_tag is not None:
        if not tag_col:
            _fail(f"inbounds table does not have a tag column. Columns: {cols}")
        where = f"{tag_col}=?"
        params = (inbound_tag,)
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

    # Row mapping depends on select order.
    idx = 0
    inb_id = int(row[idx]); idx += 1
    inb_port = int(row[idx]) if port_col else 0; idx += 1 if port_col else 0
    inb_tag = str(row[idx]) if tag_col else ""; idx += 1 if tag_col else 0
    settings_raw = row[idx]; idx += 1
    stream_raw = row[idx] if stream_col else None

    settings = _load_json_maybe(settings_raw)
    stream = _load_json_maybe(stream_raw)
    return Inbound(id=inb_id, port=inb_port, tag=inb_tag, settings=settings, stream=stream), settings_col, stream_col


def main() -> None:
    ap = argparse.ArgumentParser(description="Add a VLESS client into x-ui inbound (SQLite).")
    ap.add_argument("--db", default="/etc/x-ui/x-ui.db", help="Path to x-ui SQLite db (default: /etc/x-ui/x-ui.db)")
    ap.add_argument("--inbound-id", type=int, default=None)
    ap.add_argument("--inbound-port", type=int, default=None)
    ap.add_argument("--inbound-tag", default=None)
    ap.add_argument("--email", required=True, help="Client email/label (x-ui uses this as identifier)")
    ap.add_argument("--uuid", default=None, help="Client UUID (default: random uuid4)")
    ap.add_argument("--flow", default="xtls-rprx-vision", help="VLESS flow (default: xtls-rprx-vision)")

    # Link output is optional: needs server host and ability to derive pbk.
    ap.add_argument(
        "--template-vless-link",
        default=None,
        help="Optional vless:// link exported from x-ui (used as a template to extract pbk/sni/sid/fp/type).",
    )
    ap.add_argument("--server", default=None, help="Public host/IP for vless:// link (optional)")
    ap.add_argument("--label", default=None, help="Link label (default: email)")
    ap.add_argument("--sni", default=None, help="Override SNI (default: first reality serverNames)")
    ap.add_argument("--sid", default=None, help="Override shortId (default: first reality shortIds)")
    ap.add_argument("--pbk", default=None, help="Override REALITY public key (pbk). If set, no derivation is needed.")
    ap.add_argument("--fp", default="chrome", help="Fingerprint (default: chrome)")
    ap.add_argument("--type", dest="typ", default="tcp", help="Transport type (default: tcp)")
    ap.add_argument("--json", action="store_true", help="Print JSON output (default)")
    ap.add_argument("--print-link", action="store_true", help="Print only vless:// link if built")
    args = ap.parse_args()

    if not os.path.exists(args.db):
        _fail(f"DB file not found: {args.db}")

    client_uuid = args.uuid or str(uuidlib.uuid4())
    # Minimal sanity check to avoid breaking JSON.
    try:
        uuidlib.UUID(client_uuid)
    except Exception:
        _fail(f"Invalid UUID: {client_uuid}")

    con = sqlite3.connect(args.db)
    cur = con.cursor()

    if not _table_exists(cur, "inbounds"):
        _fail("DB does not contain 'inbounds' table. Is this an x-ui DB?")

    inbound, settings_col, _stream_col = _load_inbound(
        cur,
        inbound_id=args.inbound_id,
        inbound_port=args.inbound_port,
        inbound_tag=args.inbound_tag,
    )

    # Append client.
    clients = inbound.settings.get("clients")
    if clients is None:
        inbound.settings["clients"] = []
        clients = inbound.settings["clients"]
    if not isinstance(clients, list):
        _fail("Inbound settings JSON has non-list 'clients' field; refusing to edit.")

    # Avoid duplicates.
    for c in clients:
        if isinstance(c, dict) and c.get("email") == args.email:
            _fail(f"Client with email '{args.email}' already exists in this inbound.")
        if isinstance(c, dict) and c.get("id") == client_uuid:
            _fail(f"Client with id '{client_uuid}' already exists in this inbound.")

    clients.append({"id": client_uuid, "email": args.email, "flow": args.flow})

    cur.execute(
        f"UPDATE inbounds SET {settings_col}=? WHERE id=?",
        (_dump_json(inbound.settings), inbound.id),
    )

    traffic_changed = False
    traffic_msg = ""
    try:
        traffic_changed, traffic_msg = _ensure_client_traffic_row(
            cur, inbound_id=inbound.id, email=args.email, client_uuid=client_uuid
        )
    except Exception as e:
        # Non-fatal: UI visibility may vary by fork/schema.
        traffic_changed, traffic_msg = False, f"traffic row insert failed: {e}"

    con.commit()

    out: Dict[str, Any] = {
        "ok": True,
        "email": args.email,
        "id": client_uuid,
        "flow": args.flow,
        "inbound": {"id": inbound.id, "port": inbound.port, "tag": inbound.tag},
        "traffic_row": {"changed": traffic_changed, "message": traffic_msg},
    }

    # Build link if asked / possible.
    vless = None
    template = _parse_template_vless(args.template_vless_link) if args.template_vless_link else {}
    server_for_link = (args.server or "").strip() or str(template.get("server") or "").strip()

    if server_for_link:
        reality = None
        # Different forks sometimes nest stream settings differently.
        if isinstance(inbound.stream, dict):
            reality = inbound.stream.get("realitySettings") or inbound.stream.get("reality_settings")
            if not reality and isinstance(inbound.stream.get("securitySettings"), dict):
                reality = inbound.stream["securitySettings"].get("realitySettings")
        if not isinstance(reality, dict):
            out["link_error"] = "No realitySettings found in inbound stream settings; can't build vless link."
        else:
            private_key = str(reality.get("privateKey") or "").strip()
            server_names = reality.get("serverNames")
            short_ids = reality.get("shortIds")
            sni = (args.sni or "").strip() or str(template.get("sni") or "").strip() or _pick_first_nonempty(server_names)
            sid = (args.sid or "").strip() or str(template.get("sid") or "").strip() or _pick_first_nonempty(short_ids)
            fp = (args.fp or "").strip() or str(template.get("fp") or "").strip() or "chrome"
            typ = (args.typ or "").strip() or str(template.get("type") or "").strip() or "tcp"
            if not sni or not sid:
                out["link_error"] = "Missing reality serverNames/shortIds; can't build vless link."
            else:
                pbk = (args.pbk or "").strip() or str(template.get("pbk") or "").strip()
                if not pbk:
                    if not private_key:
                        out["link_error"] = "Missing reality privateKey on server; can't derive pbk (and no pbk/template provided)."
                    else:
                        pbk = _derive_reality_public_key(private_key) or ""
                if not pbk:
                    out["link_error"] = "Can't derive pbk from privateKey (xray helper not found/unsupported). Provide --pbk or --template-vless-link from x-ui Share."
                else:
                    label = args.label or args.email
                    vless = _vless_link(
                        server_for_link,
                        int(inbound.port),
                        client_uuid,
                        label,
                        args.flow,
                        sni,
                        sid,
                        pbk,
                        fp,
                        typ,
                    )
                    out["vless_link"] = vless

    if args.print_link:
        if not vless:
            _fail(out.get("link_error") or "vless link was not built.")
        print(vless)
        return

    # Default output: JSON (stable for automation).
    print(json.dumps(out, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
