#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional, Set, Tuple
from urllib.parse import parse_qs, quote, urlparse

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
)


def _fail(msg: str, code: int = 2) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def _load_env_file(path: str) -> None:
    p = Path(path)
    if not p.exists():
        return
    for raw in p.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        v = v.strip().strip('"').strip("'")
        if not k:
            continue
        os.environ.setdefault(k, v)


def _env(name: str, default: Optional[str] = None) -> str:
    v = os.getenv(name, default)
    if v is None:
        _fail(f"Missing env var: {name}")
    return v


def _parse_int(name: str, default: Optional[int] = None) -> int:
    v = os.getenv(name)
    if v is None:
        if default is None:
            _fail(f"Missing env var: {name}")
        return default
    try:
        return int(v)
    except Exception:
        _fail(f"Env var {name} must be int, got: {v!r}")
        raise


def _parse_allowed_ids(s: str) -> Set[int]:
    out: Set[int] = set()
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        try:
            out.add(int(part))
        except Exception:
            continue
    return out


def _now_ts() -> str:
    return time.strftime("%Y%m%d-%H%M%S", time.gmtime())


def _karing_install_link(*, url: str, name: str) -> str:
    # Karing supports: karing://install-config?url=<urlencoded>&name=<urlencoded>
    # If Telegram doesn't open custom schemes directly, user can copy/paste this into Safari.
    return f"karing://install-config?url={quote(url, safe='')}&name={quote(name, safe='')}"


def _vless_link(
    *,
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


def _parse_template_vless(link: str) -> Dict[str, str]:
    link = (link or "").strip()
    if not link:
        return {}
    u = urlparse(link)
    if u.scheme.lower() != "vless":
        raise ValueError("template vless link must start with vless://")

    # netloc is "<uuid>@host:port" (uuid is irrelevant for template)
    hostport = u.netloc.rsplit("@", 1)[-1]
    host = hostport
    port = ""
    if hostport.startswith("[") and "]" in hostport:
        # [IPv6]:port
        host = hostport.split("]", 1)[0].lstrip("[")
        rest = hostport.split("]", 1)[1]
        if rest.startswith(":"):
            port = rest[1:]
    else:
        if ":" in hostport:
            host, port = hostport.rsplit(":", 1)

    q = parse_qs(u.query, keep_blank_values=True)

    def q1(key: str) -> str:
        v = q.get(key)
        if not v:
            return ""
        return str(v[0] or "").strip()

    out: Dict[str, str] = {}
    if host.strip():
        out["server"] = host.strip()
    if port.strip():
        out["port"] = port.strip()
    for k in ("pbk", "sni", "sid", "fp", "type", "flow"):
        v = q1(k)
        if v:
            out[k] = v
    return out


def _read_template_link() -> Tuple[str, Dict[str, str]]:
    file_path = os.getenv("XUI_TEMPLATE_VLESS_FILE", "").strip()
    direct = os.getenv("XUI_TEMPLATE_VLESS_LINK", "").strip()
    if file_path:
        p = Path(file_path)
        if not p.exists():
            raise FileNotFoundError(f"XUI_TEMPLATE_VLESS_FILE not found: {file_path}")
        direct = p.read_text(encoding="utf-8", errors="ignore").strip()
    if not direct:
        raise ValueError(
            "template vless is empty. Set XUI_TEMPLATE_VLESS_FILE or XUI_TEMPLATE_VLESS_LINK (export a vless:// link from x-ui Share)."
        )
    return direct, _parse_template_vless(direct)


def _load_inbound_client_uuid(*, db_path: str, inbound_port: int, email: str) -> Optional[str]:
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    cols = [r[1] for r in cur.execute("PRAGMA table_info(inbounds)")]
    settings_col = "settings" if "settings" in cols else ("setting" if "setting" in cols else "")
    if not settings_col:
        return None
    row = cur.execute(f"SELECT {settings_col} FROM inbounds WHERE port=?", (inbound_port,)).fetchone()
    if not row:
        return None
    try:
        settings = json.loads(row[0] or "{}")
    except Exception:
        return None
    for c in settings.get("clients", []) or []:
        if isinstance(c, dict) and str(c.get("email")) == email:
            cid = str(c.get("id") or "").strip()
            if cid:
                return cid
    return None


@dataclass(frozen=True)
class BotConfig:
    token: str
    admin_ids: Set[int]
    xui_db: str
    xui_inbound_port: int
    xui_server_host: str
    xui_flow: str
    output_dir: str
    lock_file: str
    pending_file: str
    lock_wait_secs: float
    create_timeout_secs: float


def _load_config() -> BotConfig:
    token = _env("BOT_TOKEN")
    admin_raw = os.getenv("BOT_ADMIN_IDS", "").strip()
    if not admin_raw:
        # Backward compatible: old name.
        admin_raw = os.getenv("BOT_ALLOWED_IDS", "").strip()
    admins = _parse_allowed_ids(admin_raw)
    if not admins:
        _fail("Set BOT_ADMIN_IDS (comma-separated Telegram user ids) for approval flow.")
    xui_db = os.getenv("XUI_DB", "/etc/x-ui/x-ui.db").strip()
    inbound_port = _parse_int("XUI_INBOUND_PORT", 32062)
    server_host = _env("XUI_SERVER_HOST")
    flow = os.getenv("XUI_FLOW", "xtls-rprx-vision").strip()
    output_dir = os.getenv("BOT_OUTPUT_DIR", "/var/lib/vpn-onboard").strip()
    lock_file = os.getenv("BOT_LOCK_FILE", "/var/lock/vpn-onboard-xui.lock").strip()
    pending_file = os.getenv("BOT_PENDING_FILE", "/var/lib/vpn-onboard/pending.json").strip()
    lock_wait_secs = float(os.getenv("BOT_LOCK_WAIT_SECS", "30").strip() or "30")
    create_timeout_secs = float(os.getenv("BOT_CREATE_TIMEOUT_SECS", "90").strip() or "90")
    return BotConfig(
        token=token,
        admin_ids=admins,
        xui_db=xui_db,
        xui_inbound_port=inbound_port,
        xui_server_host=server_host,
        xui_flow=flow,
        output_dir=output_dir,
        lock_file=lock_file,
        pending_file=pending_file,
        lock_wait_secs=lock_wait_secs,
        create_timeout_secs=create_timeout_secs,
    )


def _is_admin(cfg: BotConfig, user_id: int) -> bool:
    return user_id in cfg.admin_ids


def _repo_root() -> Path:
    # .../scripts/telegram-bot/onboard_bot.py -> repo root is two levels up.
    return Path(__file__).resolve().parents[2]


def _run_create_ios_user(
    *,
    cfg: BotConfig,
    email: str,
    template_vless_link: str,
    out_file: Path,
) -> Tuple[int, str, str, Optional[Dict[str, Any]]]:
    """
    Returns (exit_code, stdout, stderr, parsed_json_if_any).
    """
    out_file.parent.mkdir(parents=True, exist_ok=True)
    script = _repo_root() / "scripts" / "x-ui" / "create-ios-user.sh"

    cmd = [
        "bash",
        str(script),
        "--email",
        email,
        "--server",
        cfg.xui_server_host,
        "--inbound-port",
        str(cfg.xui_inbound_port),
        "--flow",
        cfg.xui_flow,
        "--template-vless-link",
        template_vless_link,
        "--out",
        str(out_file),
        "--db",
        cfg.xui_db,
    ]
    try:
        p = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=cfg.create_timeout_secs,
        )
    except subprocess.TimeoutExpired as e:
        # Return a clear error; caller will report to admin/user.
        return 124, (e.stdout or ""), (e.stderr or "timeout"), None

    js: Optional[Dict[str, Any]] = None
    json_path = Path(str(out_file) + ".json")
    if json_path.exists():
        try:
            js = json.loads(json_path.read_text(encoding="utf-8", errors="ignore") or "{}")
        except Exception:
            js = None
    return p.returncode, (p.stdout or ""), (p.stderr or ""), js


def _format_ios_message(*, email: str, vless_link: str) -> str:
    karing = _karing_install_link(url=vless_link, name=f"VPN {email}")
    # Keep it simple: Telegram may not open custom schemes; user can copy.
    return "\n".join(
        [
            "iOS (Karing) подключение готово.",
            "",
            "1) Установи Karing: https://apps.apple.com/app/karing/id6472431552",
            "",
            "2) Быстрый импорт (попробуй открыть, если Telegram не откроет, скопируй и вставь в Safari):",
            f"`{karing}`",
            "",
            "3) Если быстрый импорт не сработал: открой Karing -> Add config -> Paste from clipboard и вставь:",
            f"`{vless_link}`",
        ]
    )


def _ios_keyboard(*, email: str, vless_link: str) -> InlineKeyboardMarkup:
    # A URL button is the most reliable way to present custom schemes in Telegram.
    karing = _karing_install_link(url=vless_link, name=f"VPN-{email}")
    return InlineKeyboardMarkup([[InlineKeyboardButton("Open Karing (Auto Import)", url=karing)]])


def _ios_message(*, email: str, vless_link: str) -> str:
    karing = _karing_install_link(url=vless_link, name=f"VPN-{email}")
    return "\n".join(
        [
            "iOS (Karing) setup",
            "",
            "1) Install Karing (App Store): https://apps.apple.com/app/karing/id6472431552",
            "",
            "2) Enable scheme calls in Karing (required for auto import):",
            "   Karing -> Settings -> System Scheme Call -> enable karing://",
            "",
            "3) Auto import:",
            "   Tap the button below. If Telegram blocks it, copy this link into Notes app and tap it:",
            f"   {karing}",
            "",
            "4) Manual import (always works):",
            "   Karing -> Add config -> Paste from clipboard, then paste this vless link:",
            f"   {vless_link}",
            "",
            "Note: vless:// links won't import via Safari. They must be imported inside the VPN app.",
        ]
    )


def _pending_load(path: str) -> Dict[str, Any]:
    p = Path(path)
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8", errors="ignore") or "{}")
    except Exception:
        return {}


def _pending_save(path: str, data: Dict[str, Any]) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=True, indent=2), encoding="utf-8")


def _new_request_id() -> str:
    return uuid.uuid4().hex[:12]

def _missing_template_fields(t: Dict[str, str]) -> Tuple[str, ...]:
    # For REALITY share links we need these non-secret fields to build a vless:// link.
    missing = []
    for k in ("pbk", "sni", "sid"):
        if not (t.get(k) or "").strip():
            missing.append(k)
    return tuple(missing)


def _lock_path(path: str) -> Any:
    # Linux: fcntl lock. On non-Linux this still runs, but the bot is intended for the server.
    import fcntl  # type: ignore

    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    f = open(p, "a+", encoding="utf-8")
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    return f


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    # Access is open for everyone. Approvals are handled via BOT_ADMIN_IDS.

    kb = InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("Android", callback_data="os:android"),
                InlineKeyboardButton("iOS", callback_data="os:ios"),
            ],
            [
                InlineKeyboardButton("Windows", callback_data="os:windows"),
                InlineKeyboardButton("MacOS", callback_data="os:macos"),
            ],
        ]
    )
    await update.message.reply_text("Choose platform:", reply_markup=kb)


async def cb_choose_os(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    cfg: BotConfig = context.bot_data["cfg"]
    q = update.callback_query
    if not q:
        return
    await q.answer()

    uid = q.from_user.id if q.from_user else 0
    data = (q.data or "").strip()
    if not data.startswith("os:"):
        return

    os_name = data.split(":", 1)[1].strip().lower()
    if os_name not in ("ios", "android", "windows", "macos"):
        await q.edit_message_text("Unknown platform.")
        return

    req_id = _new_request_id()
    chat_id = q.message.chat_id if q.message else 0
    user = q.from_user
    username = f"@{user.username}" if user and user.username else ""
    display = (f"{user.first_name or ''} {user.last_name or ''}".strip() if user else "") or username or str(uid)

    store = _pending_load(cfg.pending_file)
    store[req_id] = {
        "request_id": req_id,
        "requested_os": os_name,
        "user_id": uid,
        "chat_id": chat_id,
        "username": username,
        "display": display,
        "ts": int(time.time()),
    }
    _pending_save(cfg.pending_file, store)

    await q.edit_message_text("Request sent to admin. Please wait for approval.")

    kb = InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("Approve", callback_data=f"adm:ok:{req_id}"),
                InlineKeyboardButton("Reject", callback_data=f"adm:no:{req_id}"),
            ]
        ]
    )
    admin_msg = "\n".join(
        [
            "New VPN access request:",
            f"- OS: {os_name}",
            f"- Name: {display}",
            f"- Username: {username or '-'}",
            f"- Telegram ID: {uid}",
        ]
    )
    for admin_id in sorted(cfg.admin_ids):
        try:
            await context.bot.send_message(chat_id=admin_id, text=admin_msg, reply_markup=kb)
        except Exception:
            # Admin must start the bot first.
            pass


async def cb_admin_action(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    cfg: BotConfig = context.bot_data["cfg"]
    q = update.callback_query
    if not q:
        return
    await q.answer()

    admin_id = q.from_user.id if q.from_user else 0
    if not _is_admin(cfg, admin_id):
        await q.edit_message_text("Admin only.")
        return

    data = (q.data or "").strip()
    parts = data.split(":")
    if len(parts) != 3:
        return
    _prefix, action, req_id = parts

    store = _pending_load(cfg.pending_file)
    req = store.get(req_id)
    if not isinstance(req, dict):
        await q.edit_message_text("Request not found/expired.")
        return

    requested_os = str(req.get("requested_os") or "").strip().lower()
    user_id = int(req.get("user_id") or 0)
    chat_id = int(req.get("chat_id") or 0)
    display = str(req.get("display") or user_id)
    username = str(req.get("username") or "").strip()

    if action == "no":
        store.pop(req_id, None)
        _pending_save(cfg.pending_file, store)
        await q.edit_message_text(f"Rejected: {display} ({user_id}) OS={requested_os}")
        if chat_id:
            try:
                await context.bot.send_message(chat_id=chat_id, text="Admin rejected your request.")
            except Exception:
                pass
        return

    if action != "ok":
        return

    if requested_os != "ios":
        store.pop(req_id, None)
        _pending_save(cfg.pending_file, store)
        await q.edit_message_text(f"Approved (not implemented): {display} ({user_id}) OS={requested_os}")
        if chat_id:
            try:
                await context.bot.send_message(chat_id=chat_id, text=f"Approved. {requested_os} is not implemented yet.")
            except Exception:
                pass
        return

    # iOS: create x-ui client (email = telegram user id)
    email = str(user_id)
    out_dir = Path(cfg.output_dir)
    out_file = out_dir / f"client-pack-ios-{email}.txt"

    # Immediately show progress in admin chat so it doesn't look like a "dead" button.
    try:
        await q.edit_message_text(f"Processing: {display} ({user_id}) OS=ios ...")
    except Exception:
        pass

    try:
        template_link, template = _read_template_link()
    except Exception as e:
        file_path = os.getenv("XUI_TEMPLATE_VLESS_FILE", "").strip()
        direct = os.getenv("XUI_TEMPLATE_VLESS_LINK", "").strip()
        direct_state = "set" if direct else "-"
        await q.edit_message_text(
            "\n".join(
                [
                    "Approve failed: template vless is not configured/invalid.",
                    f"- XUI_TEMPLATE_VLESS_FILE={file_path or '-'}",
                    f"- XUI_TEMPLATE_VLESS_LINK={direct_state}",
                    f"- error: {e}",
                    "Fix: set XUI_TEMPLATE_VLESS_FILE to a file that contains a single line starting with vless:// (export from x-ui Share).",
                ]
            )
        )
        return

    missing = _missing_template_fields(template)
    if missing:
        await q.edit_message_text(
            "\n".join(
                [
                    "Approve failed: template vless link is missing required REALITY fields.",
                    f"- missing: {', '.join(missing)}",
                    "Fix: export a real `vless://...` from x-ui Share/Export for this inbound.",
                    "It must include query params like `pbk=...&sni=...&sid=...`.",
                ]
            )
        )
        return

    try:
        lock_f = await asyncio.wait_for(
            asyncio.to_thread(_lock_path, cfg.lock_file),
            timeout=cfg.lock_wait_secs,
        )
    except asyncio.TimeoutError:
        await q.edit_message_text("Approve failed: server is busy (lock timeout). Try again.")
        return
    except Exception as e:
        await q.edit_message_text(f"Lock error: {e}")
        return

    try:
        rc, out, err, js = await asyncio.to_thread(
            _run_create_ios_user,
            cfg=cfg,
            email=email,
            template_vless_link=template_link,
            out_file=out_file,
        )
    finally:
        try:
            lock_f.close()
        except Exception:
            pass

    vless = ""
    client_id = ""
    if isinstance(js, dict):
        vless = str(js.get("vless_link") or "").strip()
        client_id = str(js.get("id") or "").strip()

    # If the script didn't return a vless:// link, rebuild it from DB using the template
    # (pbk/sni/sid are non-secret and stable for the inbound).
    if not vless:
        existing_uuid = _load_inbound_client_uuid(
            db_path=cfg.xui_db, inbound_port=cfg.xui_inbound_port, email=email
        )
        if existing_uuid and template.get("pbk") and template.get("sni") and template.get("sid"):
            vless = _vless_link(
                server=cfg.xui_server_host,
                port=cfg.xui_inbound_port,
                client_id=existing_uuid,
                label=email,
                flow=template.get("flow") or cfg.xui_flow,
                sni=template["sni"],
                sid=template["sid"],
                pbk=template["pbk"],
                fp=template.get("fp") or "chrome",
                typ=template.get("type") or "tcp",
            )
            client_id = existing_uuid

    if not vless:
        # Include stderr snippet for debugging.
        snippet = (err or out or "").strip().replace("\r", "")
        snippet = snippet[-700:] if snippet else ""
        await q.edit_message_text(f"Approved but failed: {display} ({user_id}) rc={rc}\n{snippet}")
        if chat_id:
            try:
                await context.bot.send_message(chat_id=chat_id, text="Approved, but failed to generate connection link. Contact admin.")
            except Exception:
                pass
        return

    store.pop(req_id, None)
    _pending_save(cfg.pending_file, store)

    await q.edit_message_text(f"Approved: {display} {username} ({user_id}) client={client_id}")
    if chat_id:
        await context.bot.send_message(
            chat_id=chat_id,
            text=_ios_message(email=email, vless_link=vless),
            reply_markup=_ios_keyboard(email=email, vless_link=vless),
            disable_web_page_preview=True,
        )
        if out_file.exists():
            try:
                await context.bot.send_document(chat_id=chat_id, document=out_file.read_bytes(), filename=out_file.name)
            except Exception:
                pass


async def post_init(app: Application) -> None:
    # Best-effort: if a webhook is set on this token, polling will fail.
    try:
        await app.bot.delete_webhook(drop_pending_updates=True)
    except Exception:
        pass


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--env-file", default="", help="Optional .env file to load (KEY=VALUE)")
    args = ap.parse_args()

    if args.env_file:
        _load_env_file(args.env_file)

    cfg = _load_config()

    app = Application.builder().token(cfg.token).post_init(post_init).build()
    app.bot_data["cfg"] = cfg

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CallbackQueryHandler(cb_choose_os, pattern=r"^os:"))
    app.add_handler(CallbackQueryHandler(cb_admin_action, pattern=r"^adm:"))

    app.run_polling(close_loop=False, allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
