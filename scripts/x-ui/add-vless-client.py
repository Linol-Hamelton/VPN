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
    con.commit()

    out: Dict[str, Any] = {
        "ok": True,
        "email": args.email,
        "id": client_uuid,
        "flow": args.flow,
        "inbound": {"id": inbound.id, "port": inbound.port, "tag": inbound.tag},
    }

    # Build link if asked / possible.
    vless = None
    if args.server:
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
            sni = args.sni or _pick_first_nonempty(server_names)
            sid = args.sid or _pick_first_nonempty(short_ids)
            if not sni or not sid:
                out["link_error"] = "Missing reality serverNames/shortIds; can't build vless link."
            elif not private_key:
                out["link_error"] = "Missing reality privateKey on server; can't derive pbk."
            else:
                pbk = (args.pbk or "").strip() or _derive_reality_public_key(private_key)
                if not pbk:
                    out["link_error"] = "Can't derive pbk from privateKey (xray helper not found/unsupported). Use x-ui Share to export vless link."
                else:
                    label = args.label or args.email
                    vless = _vless_link(
                        args.server,
                        int(inbound.port),
                        client_uuid,
                        label,
                        args.flow,
                        sni,
                        sid,
                        pbk,
                        args.fp,
                        args.typ,
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
