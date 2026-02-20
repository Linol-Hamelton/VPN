#!/usr/bin/env python3
"""VPN Client Onboarding Telegram Bot

This bot helps users connect to a VPN service by generating platform-specific
configuration instructions and providing download links for the simplified app.
"""

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
from urllib.parse import parse_qs, quote, urlparse, urlunparse

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
    """Load KEY=VALUE pairs from a file."""
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
    """Parse comma-separated integers (usually Telegram user IDs)."""
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
    # Karing deep-link (see xray deeplink docs):
    # karing://install-config?url=<urlencoded>&name=<urlencoded>
    #
    # Note: In practice, Karing expects "url=" to point to a subscription/config URL (http/https),
    # not a raw vless:// link. If you don't have a subscription URL, we still provide this deep-link
    # as a best-effort, but manual import (paste vless:// into the app) is the reliable fallback.
    return f"karing://install-config?url={quote(url, safe='')}&name={quote(name, safe='')}"


def _clash_install_link(*, url: str) -> str:
    # Clash Verge Rev deep-link (official docs):
    # clash://install-config?url=<uri_encoded_url>
    return f"clash://install-config?url={quote(url, safe='')}"


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


def _clone_template_vless(
    template_link: str,
    *,
    server: str,
    port: int,
    client_id: str,
    label: str,
) -> str:
    """
    Build a vless:// link by cloning the full query string from an x-ui "Share" template.
    This preserves optional fields (ex: spx) that some clients include in exports.
    """
    t = (template_link or "").strip()
    u = urlparse(t)
    if u.scheme.lower() != "vless":
        raise ValueError("template vless link must start with vless://")

    host = (server or "").strip()
    if not host:
        raise ValueError("server host is empty")
    if ":" in host and not host.startswith("["):
        # Likely IPv6
        host = f"[{host}]"
    netloc = f"{client_id}@{host}:{int(port)}"

    frag = quote((label or "").strip() or "x-ui", safe="")
    return urlunparse((u.scheme, netloc, u.path or "", u.params or "", u.query or "", frag))


_UUID_RE = re.compile(r"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})")


def _extract_uuid(text: str) -> str:
    m = _UUID_RE.search(text or "")
    return (m.group(1) if m else "").strip()


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


def _load_inbound_client_identity(*, db_path: str, inbound_port: int, email: str) -> Tuple[str, str]:
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    cols = [r[1] for r in cur.execute("PRAGMA table_info(inbounds)")]
    settings_col = "settings" if "settings" in cols else ("setting" if "setting" in cols else "")
    if not settings_col:
        return "", ""
    row = cur.execute(f"SELECT {settings_col} FROM inbounds WHERE port=?", (inbound_port,)).fetchone()
    if not row:
        return "", ""
    try:
        settings = json.loads(row[0] or "{}")
    except Exception:
        return "", ""
    for c in settings.get("clients", []) or []:
        if isinstance(c, dict) and str(c.get("email")) == email:
            cid = str(c.get("id") or "").strip()
            sub_id = str(c.get("subId") or "").strip()
            return cid, sub_id
    return "", ""


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
    xui_sub_url_template: str
    xui_clash_sub_url_template: str
    xui_clash_bridge_url_template: str
    xui_hiddify_bridge_url_template: str
    send_client_pack: bool
    package_map_file: str


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
    sub_url_template = os.getenv("XUI_SUB_URL_TEMPLATE", "").strip()
    clash_sub_url_template = os.getenv("XUI_CLASH_SUB_URL_TEMPLATE", "").strip()
    clash_bridge_url_template = os.getenv("XUI_CLASH_BRIDGE_URL_TEMPLATE", "").strip()
    hiddify_bridge_url_template = os.getenv(
        "XUI_HIDDIFY_BRIDGE_URL_TEMPLATE",
        "http://{server}:25501/h-open?sub={sub_url_enc}&name=VPN-{email}",
    ).strip()
    send_client_pack = (os.getenv("BOT_SEND_CLIENT_PACK", "0").strip().lower() in ("1", "true", "yes", "y", "on"))
    package_map_file = os.getenv("BOT_PACKAGE_FILE_MAP", "/var/lib/vpn-onboard/package_files.json").strip()
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
        xui_sub_url_template=sub_url_template,
        xui_clash_sub_url_template=clash_sub_url_template,
        xui_clash_bridge_url_template=clash_bridge_url_template,
        xui_hiddify_bridge_url_template=hiddify_bridge_url_template,
        send_client_pack=send_client_pack,
        package_map_file=package_map_file,
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


def _render_url_template(*, tpl: str, cfg: BotConfig, email: str, client_id: str, sub_id: str) -> str:
    tpl = (tpl or "").strip()
    if not tpl:
        return ""
    # Supported placeholders: {email}, {uuid}, {client_id}, {sub_id}, {subid}, {server}, {port}
    try:
        return tpl.format(
            email=email,
            uuid=client_id,
            client_id=client_id,
            sub_id=sub_id,
            subid=sub_id,
            server=cfg.xui_server_host,
            port=str(cfg.xui_inbound_port),
        ).strip()
    except Exception:
        # Misconfigured template.
        return ""


def _render_sub_url(*, cfg: BotConfig, email: str, client_id: str, sub_id: str) -> str:
    """
    Optional iOS subscription URL template (for Karing deep-link URL param).
    """
    return _render_url_template(
        tpl=cfg.xui_sub_url_template, cfg=cfg, email=email, client_id=client_id, sub_id=sub_id
    )


def _render_clash_sub_url(*, cfg: BotConfig, email: str, client_id: str, sub_id: str) -> str:
    """
    Optional Windows Clash subscription/config URL template.
    This URL must be HTTP(S) and return a Clash-compatible config/subscription.
    """
    return _render_url_template(
        tpl=cfg.xui_clash_sub_url_template, cfg=cfg, email=email, client_id=client_id, sub_id=sub_id
    )


def _render_clash_bridge_url(
    *,
    cfg: BotConfig,
    email: str,
    client_id: str,
    sub_id: str,
    sub_url: str,
    clash_link: str,
) -> str:
    """
    Optional HTTP bridge page that immediately opens clash:// link.
    This is needed because Telegram URL buttons do not support custom schemes.
    """
    tpl = (cfg.xui_clash_bridge_url_template or "").strip()
    if not tpl:
        return ""
    try:
        return tpl.format(
            email=email,
            uuid=client_id,
            client_id=client_id,
            sub_id=sub_id,
            subid=sub_id,
            server=cfg.xui_server_host,
            port=str(cfg.xui_inbound_port),
            sub_url=sub_url,
            sub_url_enc=quote(sub_url, safe=""),
            clash_link=clash_link,
            clash_link_enc=quote(clash_link, safe=""),
        ).strip()
    except Exception:
        return ""


def _render_hiddify_bridge_url(
    *,
    cfg: BotConfig,
    email: str,
    client_id: str,
    sub_id: str,
    sub_url: str,
    hiddify_link: str,
) -> str:
    tpl = (cfg.xui_hiddify_bridge_url_template or "").strip()
    if not tpl:
        return ""
    try:
        return tpl.format(
            email=email,
            uuid=client_id,
            client_id=client_id,
            sub_id=sub_id,
            subid=sub_id,
            server=cfg.xui_server_host,
            port=str(cfg.xui_inbound_port),
            sub_url=sub_url,
            sub_url_enc=quote(sub_url, safe=""),
            hiddify_link=hiddify_link,
            hiddify_link_enc=quote(hiddify_link, safe=""),
        ).strip()
    except Exception:
        return ""


def _ios_karing_link(*, cfg: BotConfig, email: str, vless_link: str, client_id: str, sub_id: str) -> Tuple[str, bool]:
    sub_url = _render_sub_url(cfg=cfg, email=email, client_id=client_id, sub_id=sub_id)
    if not sub_url:
        return "", False
    return _karing_install_link(url=sub_url, name=f"VPN-{email}"), True


def _ios_keyboard(*, karing_link: str) -> Optional[InlineKeyboardMarkup]:
    # IPA delivered via send_document — no extra keyboard button needed.
    return None


def _windows_clash_link(*, cfg: BotConfig, email: str, client_id: str, sub_id: str) -> Tuple[str, str, str]:
    """
    Returns (clash_deeplink, clash_subscription_url, clash_auto_import_url).
    """
    sub_url = _render_clash_sub_url(cfg=cfg, email=email, client_id=client_id, sub_id=sub_id)
    if not sub_url:
        return "", "", ""
    clash_link = _clash_install_link(url=sub_url)
    bridge_url = _render_clash_bridge_url(
        cfg=cfg,
        email=email,
        client_id=client_id,
        sub_id=sub_id,
        sub_url=sub_url,
        clash_link=clash_link,
    )
    return clash_link, sub_url, bridge_url


def _windows_keyboard(*, auto_url: str, sub_url: str) -> Optional[InlineKeyboardMarkup]:
    # Telegram inline buttons do NOT support custom schemes like clash://.
    # Use an HTTP bridge for one-click.
    rows = []
    if auto_url:
        rows.append([InlineKeyboardButton("Open Clash Verge Auto Import", url=auto_url)])
    if not rows:
        return None
    return InlineKeyboardMarkup(rows)


def _windows_message(*, clash_link: str, vless_link: str) -> str:
    def inline_code(s: str) -> str:
        return "`" + (s or "").strip() + "`"

    lines = [
        "Windows — подключение готово.",
        "",
        "1) Установи приложение VPN (файл .exe будет отправлен ниже).",
        "   Запусти установщик и следуй инструкциям.",
        "",
    ]

    if clash_link:
        lines += [
            "2) Авто-импорт профиля VPN (нажми кнопку под сообщением):",
            inline_code(clash_link),
            "",
            "3) Ручной импорт (если авто не сработал):",
            "   Открой приложение → '+' → вставь ссылку:",
            inline_code(vless_link),
        ]
    else:
        lines += [
            "2) Добавь профиль VPN:",
            "   Открой приложение → нажми '+' → вставь ссылку:",
            inline_code(vless_link),
            "",
            "3) Нажми 'Подключиться' — готово.",
        ]

    return "\n".join(lines)


def _macos_message(*, vless_link: str) -> str:
    def inline_code(s: str) -> str:
        return "`" + (s or "").strip() + "`"

    lines = [
        "macOS — подключение готово.",
        "",
        "1) Установи приложение VPN (файл .dmg будет отправлен ниже).",
        "   Открой .dmg → перетащи приложение в папку Applications.",
        "",
        "   Важно: при первом запуске macOS покажет предупреждение безопасности.",
        "   Зайди в Системные настройки → Конфиденциальность и безопасность → нажми 'Всё равно открыть'.",
        "",
        "2) Открой приложение → нажми 'Добавить профиль' → вставь ссылку:",
        inline_code(vless_link),
        "",
        "3) Нажми 'Подключиться' — готово.",
    ]

    return "\n".join(lines)


def _hiddify_import_link(*, url: str, name: str) -> str:
    # Official Hiddify URL scheme:
    # hiddify://import/<sublink>#<name>
    if not (url or "").strip():
        return ""
    # URL-encode nested subscription URL so Telegram doesn't auto-detect the inner
    # http(s) part as a separate link and open browser page instead of Hiddify.
    enc_url = quote(url.strip(), safe="")
    enc_name = quote((name or "").strip() or "VPN", safe="")
    return f"hiddify://import/{enc_url}#{enc_name}"


def _android_links(*, cfg: BotConfig, email: str, client_id: str, sub_id: str) -> Tuple[str, str, str]:
    sub_url = _render_sub_url(cfg=cfg, email=email, client_id=client_id, sub_id=sub_id)
    if not sub_url:
        return "", "", ""
    hiddify_link = _hiddify_import_link(url=sub_url, name=f"VPN-{email}")
    auto_url = _render_hiddify_bridge_url(
        cfg=cfg,
        email=email,
        client_id=client_id,
        sub_id=sub_id,
        sub_url=sub_url,
        hiddify_link=hiddify_link,
    )
    return hiddify_link, sub_url, auto_url


def _android_keyboard(*, auto_url: str) -> Optional[InlineKeyboardMarkup]:
    if not auto_url:
        return None
    return InlineKeyboardMarkup([[InlineKeyboardButton("Open Hiddify Auto Import", url=auto_url)]])


def _android_message(*, cfg: BotConfig, email: str, vless_link: str, client_id: str, sub_id: str) -> str:
    hiddify_link, sub_url, auto_url = _android_links(cfg=cfg, email=email, client_id=client_id, sub_id=sub_id)

    def inline_code(s: str) -> str:
        return "`" + (s or "").strip() + "`"

    lines = [
        "Android (Hiddify Next) подключение готово.",
        "",
        "1) Установи Hiddify Next (Google Play):",
        "https://play.google.com/store/apps/details?id=app.hiddify.com",
        "",
    ]

    if hiddify_link:
        auto_line = auto_url
        if auto_url:
            auto_line = f"[Open Hiddify Auto Import]({auto_url})"
        lines += [
            "2) Авто-импорт (в 1 клик):",
            auto_line or hiddify_link,
            "Если Telegram не откроет приложение, скопируй эту ссылку в браузер и подтверди открытие Hiddify.",
            "",
            "3) Ручной импорт (если авто-импорт не сработал):",
        ]
    else:
        lines += [
            "2) Авто-импорт недоступен: не настроен subscription URL на сервере.",
            "",
            "3) Ручной импорт:",
        ]

    lines += [
        "Открой Hiddify -> нажми '+' -> Add from Clipboard и вставь:",
        inline_code(vless_link),
    ]

    if sub_url:
        lines += [
            "",
            "Либо добавь подписку вручную (удобно для автообновлений):",
            inline_code(sub_url),
        ]

    lines += [
        "",
        "4) Выбери профиль и нажми Подключить (разреши VPN-доступ, когда Android спросит).",
    ]

    return "\n".join(lines)


def _ios_message(*, cfg: BotConfig, email: str, vless_link: str, client_id: str, sub_id: str) -> str:
    def inline_code(s: str) -> str:
        return "`" + (s or "").strip() + "`"

    lines = [
        "iOS — подключение готово.",
        "",
        "1) Установи приложение VPN (файл .ipa будет отправлен ниже).",
        "",
        "Как установить .ipa на iPhone:",
        "   a) Через AltStore: открой AltStore на iPhone → My Apps → '+' → выбери .ipa файл",
        "   б) Через Sideloadly: подключи iPhone к ПК/Mac, открой Sideloadly, перетащи .ipa и нажми Start",
        "",
        "2) После установки открой приложение → нажми 'Добавить профиль' → вставь ссылку:",
        inline_code(vless_link),
        "",
        "3) Нажми 'Подключиться' — готово.",
    ]

    return "\n".join(lines)


def _get_download_links_for_platform(os_name: str) -> str:
    """Return download links for our simplified VPN client for each platform"""
    # These should be updated to point to your actual download locations on the domain
    # Using the user's domain vm779762.hosted-by.u1host.com with IP 144.31.227.53
    links = {
        "ios": "https://vm779762.hosted-by.u1host.com/downloads/hiddify-ios.ipa",  # Replace with actual download
        "android": "https://vm779762.hosted-by.u1host.com/downloads/hiddify-android.apk",  # Replace with actual download
        "windows": "https://vm779762.hosted-by.u1host.com/downloads/hiddify-windows.exe",  # Replace with actual download
        "macos": "https://vm779762.hosted-by.u1host.com/downloads/hiddify-macos.dmg",  # Replace with actual download
        "linux": "https://vm779762.hosted-by.u1host.com/downloads/hiddify-linux.AppImage",  # Replace with actual download
    }
    return links.get(os_name.lower(), "Ссылка скоро будет добавлена")


def _get_simple_vpn_app_message(os_name: str, vless_link: str) -> str:
    """Message for our simplified VPN client that has only 3 buttons: Add Profile, Start VPN, Settings"""

    def inline_code(s: str) -> str:
        return "`" + (s or "").strip() + "`"

    hiddify_link = _hiddify_import_link(url=vless_link, name="VPN")

    lines = [
        f"Ваш профиль VPN для {os_name.capitalize()} готов!",
        "",
        "1) Установите приложение VPN (файл отправлен ниже в этом чате).",
        "",
        "2) После установки откройте приложение.",
        "",
        "3) Автоподключение — скопируй и открой в браузере или нажми прямо здесь:",
        hiddify_link,
        "",
        "4) Ручной импорт (если авто не сработало): нажми 'Добавить профиль' и вставь:",
        inline_code(vless_link),
        "",
        "5) Нажмите 'Запустить VPN' для подключения.",
        "",
        "6) В разделе 'Настройки' можно изменить параметры или отключить VPN.",
    ]

    return "\n".join(lines)


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


def _normalize_platform(name: str) -> str:
    s = (name or "").strip().lower()
    mapping = {
        "ios": "ios",
        "iphone": "ios",
        "ipad": "ios",
        "android": "android",
        "win": "windows",
        "windows": "windows",
        "mac": "macos",
        "macos": "macos",
        "osx": "macos",
        "linux": "linux",
    }
    return mapping.get(s, "")


def _package_load(path: str) -> Dict[str, Any]:
    p = Path(path)
    if not p.exists():
        return {}
    try:
        data = json.loads(p.read_text(encoding="utf-8", errors="ignore") or "{}")
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _package_save(path: str, data: Dict[str, Any]) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=True, indent=2), encoding="utf-8")


def _package_get(path: str, platform: str) -> Optional[Dict[str, Any]]:
    store = _package_load(path)
    rec = store.get(platform)
    return rec if isinstance(rec, dict) else None


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
    """Welcome message with clear instruction for the new simplified VPN app"""
    # First, send welcome message
    await update.message.reply_text(
        "Добро пожаловать! Нажмите 'Начать', чтобы получить доступ к упрощенному приложению VPN с интерфейсом из 3 кнопок: добавить профиль, запустить VPN и настройки."
    )
    
    # Then show platform selection
    kb = InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("Начать", callback_data="choose_platform"),
            ]
        ]
    )
    await update.message.reply_text("Нажмите 'Начать', чтобы выбрать платформу для вашего устройства:", reply_markup=kb)


async def cmd_setpkg(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    cfg: BotConfig = context.bot_data["cfg"]
    msg = update.message
    if not msg:
        return
    user_id = msg.from_user.id if msg.from_user else 0
    if not _is_admin(cfg, user_id):
        await msg.reply_text("Admin only.")
        return

    if not context.args:
        await msg.reply_text("Usage: reply to a document with /setpkg <ios|android|windows|macos|linux>")
        return

    platform = _normalize_platform(context.args[0])
    if not platform:
        await msg.reply_text("Unknown platform. Use: ios, android, windows, macos, linux.")
        return

    if not msg.reply_to_message or not msg.reply_to_message.document:
        await msg.reply_text("Reply to a document with /setpkg <platform>.")
        return

    doc = msg.reply_to_message.document
    store = _package_load(cfg.package_map_file)
    store[platform] = {
        "file_id": doc.file_id,
        "file_name": doc.file_name or "",
        "mime_type": doc.mime_type or "",
        "updated_ts": int(time.time()),
    }
    _package_save(cfg.package_map_file, store)
    await msg.reply_text(f"Package saved for {platform}: {doc.file_name or doc.file_id}")


async def cmd_getpkg(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    cfg: BotConfig = context.bot_data["cfg"]
    msg = update.message
    if not msg:
        return
    user_id = msg.from_user.id if msg.from_user else 0
    if not _is_admin(cfg, user_id):
        await msg.reply_text("Admin only.")
        return

    store = _package_load(cfg.package_map_file)
    if not store:
        await msg.reply_text("No packages configured.")
        return

    lines = ["Configured packages:"]
    for platform in sorted(store.keys()):
        rec = store.get(platform) or {}
        name = rec.get("file_name") or rec.get("file_id") or "-"
        lines.append(f"- {platform}: {name}")
    await msg.reply_text("\n".join(lines))


async def cmd_delpkg(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    cfg: BotConfig = context.bot_data["cfg"]
    msg = update.message
    if not msg:
        return
    user_id = msg.from_user.id if msg.from_user else 0
    if not _is_admin(cfg, user_id):
        await msg.reply_text("Admin only.")
        return

    if not context.args:
        await msg.reply_text("Usage: /delpkg <ios|android|windows|macos|linux>")
        return

    platform = _normalize_platform(context.args[0])
    if not platform:
        await msg.reply_text("Unknown platform. Use: ios, android, windows, macos, linux.")
        return

    store = _package_load(cfg.package_map_file)
    if platform in store:
        store.pop(platform, None)
        _package_save(cfg.package_map_file, store)
        await msg.reply_text(f"Package removed for {platform}.")
    else:
        await msg.reply_text(f"No package configured for {platform}.")


async def cmd_choose_platform(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Platform selection interface with all 4 platforms"""
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
    if update.callback_query and update.callback_query.message:
        await update.callback_query.edit_message_text("Выберите платформу вашего устройства:", reply_markup=kb)
        return
    if update.message:
        await update.message.reply_text("Выберите платформу вашего устройства:", reply_markup=kb)


async def cb_choose_os(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Process user platform choice and send request to admin"""
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
        await q.edit_message_text("Неизвестная платформа.")
        return

    now_ts = int(time.time())
    req_id = _new_request_id()
    chat_id = q.message.chat_id if q.message else 0
    user = q.from_user
    username = f"@{user.username}" if user and user.username else ""
    display = (f"{user.first_name or ''} {user.last_name or ''}".strip() if user else "") or username or str(uid)

    store = _pending_load(cfg.pending_file)
    # Prevent duplicate pending requests from double taps.
    for old in store.values():
        if not isinstance(old, dict):
            continue
        if int(old.get("user_id") or 0) != uid:
            continue
        if str(old.get("requested_os") or "").strip().lower() != os_name:
            continue
        age = now_ts - int(old.get("ts") or 0)
        if 0 <= age <= 900:
            await q.edit_message_text("Запрос уже отправлен администратору. Пожалуйста, подождите подтверждения.")
            return

    store[req_id] = {
        "request_id": req_id,
        "requested_os": os_name,
        "user_id": uid,
        "chat_id": chat_id,
        "username": username,
        "display": display,
        "ts": now_ts,
    }
    _pending_save(cfg.pending_file, store)

    await q.edit_message_text("Запрос отправлен администратору. Пожалуйста, подождите подтверждения.")

    kb = InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("Подтвердить", callback_data=f"adm:ok:{req_id}"),
                InlineKeyboardButton("Отклонить", callback_data=f"adm:no:{req_id}"),
            ]
        ]
    )
    admin_msg = "\n".join(
        [
            "Новый запрос на доступ к VPN:",
            f"- ОС: {os_name}",
            f"- Имя: {display}",
            f"- Имя пользователя: {username or '-'}",
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
    """Handle admin approval/rejection of user request"""
    cfg: BotConfig = context.bot_data["cfg"]
    q = update.callback_query
    if not q:
        return
    await q.answer()

    admin_id = q.from_user.id if q.from_user else 0
    if not _is_admin(cfg, admin_id):
        await q.edit_message_text("Только для администраторов.")
        return

    data = (q.data or "").strip()
    parts = data.split(":")
    if len(parts) != 3:
        return
    _prefix, action, req_id = parts

    store = _pending_load(cfg.pending_file)
    req = store.get(req_id)
    if not isinstance(req, dict):
        await q.edit_message_text("Запрос не найден или просрочен.")
        return

    requested_os = str(req.get("requested_os") or "").strip().lower()
    user_id = int(req.get("user_id") or 0)
    chat_id = int(req.get("chat_id") or 0)
    display = str(req.get("display") or user_id)
    username = str(req.get("username") or "").strip()

    if action == "no":
        store.pop(req_id, None)
        _pending_save(cfg.pending_file, store)
        await q.edit_message_text(f"Отклонено: {display} ({user_id}) OS={requested_os}")
        if chat_id:
            try:
                await context.bot.send_message(chat_id=chat_id, text="Администратор отклонил ваш запрос.")
            except Exception:
                pass
        return

    if action != "ok":
        return

    # Consume the request immediately to prevent duplicate Approve taps
    # from creating multiple clients.
    store.pop(req_id, None)
    _pending_save(cfg.pending_file, store)

    if requested_os not in ("ios", "windows", "android", "macos"):
        await q.edit_message_text(f"Подтверждено (не реализовано): {display} ({user_id}) OS={requested_os}")
        if chat_id:
            try:
                await context.bot.send_message(chat_id=chat_id, text=f"Подтверждено. {requested_os} пока не реализовано.")
            except Exception:
                pass
        return

    # iOS/Windows/Android/macOS: create x-ui client (email = telegram user id)
    email = str(user_id)
    out_dir = Path(cfg.output_dir)
    out_file = out_dir / f"client-pack-{requested_os}-{email}.txt"

    # Immediately show progress in admin chat so it doesn't look like a "dead" button.
    try:
        await q.edit_message_text(f"Обработка: {display} ({user_id}) OS={requested_os} ...")
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
                    "Ошибка при подтверждении: шаблон vless не настроен или недействителен.",
                    f"- XUI_TEMPLATE_VLESS_FILE={file_path or '-'}",
                    f"- XUI_TEMPLATE_VLESS_LINK={direct_state}",
                    f"- ошибка: {e}",
                    "Решение: установите XUI_TEMPLATE_VLESS_FILE на файл, содержащий одну строку, начинающуюся с vless:// (экспорт из x-ui Share).",
                ]
            )
        )
        return

    missing = _missing_template_fields(template)
    if missing:
        await q.edit_message_text(
            "\n".join(
                [
                    "Ошибка при подтверждении: в шаблоне vless отсутствуют необходимые поля REALITY.",
                    f"- отсутствует: {', '.join(missing)}",
                    "Решение: экспортируйте реальный `vless://...` из x-ui Share/Export для этого inbound.",
                    "Он должен включать параметры запроса такие как `pbk=...&sni=...&sid=...`.",
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
        await q.edit_message_text("Ошибка при подтверждении: сервер занят (таймаут блокировки). Попробуйте еще раз.")
        return
    except Exception as e:
        await q.edit_message_text(f"Ошибка блокировки: {e}")
        return

    try:
        # Deduplicate by email: if client already exists, reuse it.
        existing_id, existing_sub_id = _load_inbound_client_identity(
            db_path=cfg.xui_db, inbound_port=cfg.xui_inbound_port, email=email
        )
        if existing_id:
            rc, out, err = 0, "существующий клиент повторно использован", ""
            js = {"id": existing_id, "sub_id": existing_sub_id}
        else:
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
    sub_id = ""
    if isinstance(js, dict):
        vless = str(js.get("vless_link") or "").strip()
        client_id = str(js.get("id") or "").strip()
        sub_id = str(js.get("sub_id") or "").strip()

    # If the script didn't return a vless:// link, rebuild it from the template.
    # Prefer the created client UUID from JSON/stdout; fall back to DB lookup as last resort.
    if not vless:
        uuid_to_use = client_id or _extract_uuid("\n".join([out or "", err or ""]))
        if not uuid_to_use:
            db_uuid, db_sub = _load_inbound_client_identity(
                db_path=cfg.xui_db, inbound_port=cfg.xui_inbound_port, email=email
            )
            uuid_to_use = db_uuid or ""
            if not sub_id:
                sub_id = db_sub or ""
        if uuid_to_use:
            vless = _clone_template_vless(
                template_link,
                server=cfg.xui_server_host,
                port=cfg.xui_inbound_port,
                client_id=uuid_to_use,
                label=email,
            )
            client_id = uuid_to_use

    # Windows flow can work with clash subscription URL + client UUID even without vless://.
    if not client_id:
        client_id = _extract_uuid("\n".join([out or "", err or ""])) or ""
    if not client_id or not sub_id:
        db_uuid, db_sub = _load_inbound_client_identity(
            db_path=cfg.xui_db, inbound_port=cfg.xui_inbound_port, email=email
        )
        if not client_id:
            client_id = db_uuid or ""
        if not sub_id:
            sub_id = db_sub or ""

    if not vless:
        # Include stderr snippet for debugging.
        snippet = (err or out or "").strip().replace("\r", "")
        snippet = snippet[-700:] if snippet else ""
        await q.edit_message_text(f"Подтверждено, но ошибка: {display} ({user_id}) rc={rc}\n{snippet}")
        if chat_id:
            try:
                await context.bot.send_message(chat_id=chat_id, text="Подтверждено, но произошла ошибка при генерации ссылки подключения. Обратитесь к администратору.")
            except Exception:
                pass
        return

    await q.edit_message_text(f"Подтверждено: {display} {username} ({user_id}) client={client_id}")
    if chat_id:
        # Build platform-specific message and keyboard
        delivery_text = _get_simple_vpn_app_message(requested_os, vless)
        delivery_keyboard = None
        delivery_link = ""
        
        parse_mode = "Markdown"

        try:
            await context.bot.send_message(
                chat_id=chat_id,
                text=delivery_text,
                reply_markup=delivery_keyboard,
                disable_web_page_preview=True,
                parse_mode=parse_mode,
            )
        except Exception as e:
            # Some Telegram clients reject custom schemes in URL buttons.
            try:
                await context.bot.send_message(
                    chat_id=chat_id,
                    text=delivery_text,
                    disable_web_page_preview=True,
                    parse_mode=None,
                )
            except Exception:
                pass
            try:
                await context.bot.send_message(
                    chat_id=admin_id,
                    text="\n".join(
                        [
                            f"Предупреждение: невозможно отправить пользователю сообщение с кнопкой URL ({display} {username} {user_id}).",
                            f"- ошибка: {e}",
                            f"- deeplink: {delivery_link or '-'}",
                        ]
                    ),
                    disable_web_page_preview=True,
                )
            except Exception:
                pass

        pkg = _package_get(cfg.package_map_file, requested_os)
        if pkg:
            try:
                await context.bot.send_document(
                    chat_id=chat_id,
                    document=str(pkg.get("file_id") or ""),
                    filename=(pkg.get("file_name") or None),
                )
            except Exception as e:
                try:
                    await context.bot.send_message(
                        chat_id=admin_id,
                        text=f"Package send failed ({requested_os}): {e}",
                        disable_web_page_preview=True,
                    )
                except Exception:
                    pass

        if cfg.send_client_pack and out_file.exists():
            try:
                await context.bot.send_document(chat_id=chat_id, document=out_file.read_bytes(), filename=out_file.name)
            except Exception:
                pass


async def cmd_choose_platform_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Callback handler for the choose platform button"""
    query = update.callback_query
    await query.answer()
    # Call the platform selection function
    await cmd_choose_platform(update, context)


async def post_init(app: Application) -> None:
    """Initialize the bot application"""
    # Best-effort: if a webhook is set on this token, polling will fail.
    try:
        await app.bot.delete_webhook(drop_pending_updates=True)
    except Exception:
        pass


def main() -> None:
    """Main entry point for the VPN onboarding bot"""
    ap = argparse.ArgumentParser()
    ap.add_argument("--env-file", default="", help="Optional .env file to load (KEY=VALUE)")
    args = ap.parse_args()

    if args.env_file:
        _load_env_file(args.env_file)

    cfg = _load_config()

    app = Application.builder().token(cfg.token).post_init(post_init).build()
    app.bot_data["cfg"] = cfg

    # Register handlers for the new simplified workflow
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("setpkg", cmd_setpkg))
    app.add_handler(CommandHandler("getpkg", cmd_getpkg))
    app.add_handler(CommandHandler("delpkg", cmd_delpkg))
    app.add_handler(CallbackQueryHandler(cmd_choose_platform_callback, pattern=r"^choose_platform"))
    app.add_handler(CallbackQueryHandler(cb_choose_os, pattern=r"^os:"))
    app.add_handler(CallbackQueryHandler(cb_admin_action, pattern=r"^adm:"))

    app.run_polling(close_loop=False, allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
