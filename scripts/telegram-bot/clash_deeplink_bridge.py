#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, quote, urlparse


def _build_clash_link(sub_url: str) -> str:
    return f"clash://install-config?url={quote(sub_url, safe='')}"


def _valid_sub_url(sub_url: str) -> bool:
    try:
        u = urlparse(sub_url.strip())
    except Exception:
        return False
    return u.scheme in ("http", "https") and bool(u.netloc)


def _html_page(sub_url: str, clash_link: str) -> str:
    sub_esc = html.escape(sub_url, quote=True)
    clash_esc = html.escape(clash_link, quote=True)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Open Clash Verge</title>
  <meta http-equiv="refresh" content="0;url={clash_esc}">
  <style>
    body {{ font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; }}
    .card {{ border: 1px solid #ddd; border-radius: 12px; padding: 1rem; }}
    code {{ word-break: break-all; }}
    a.btn {{ display: inline-block; padding: .7rem 1rem; border-radius: 10px; text-decoration: none; border: 1px solid #444; }}
  </style>
</head>
<body>
  <div class="card">
    <h2>Opening Clash Verge...</h2>
    <p>If app did not open automatically, click:</p>
    <p><a class="btn" href="{clash_esc}">Open Clash Verge Auto Import</a></p>
    <p>Raw clash:// link:</p>
    <p><code>{clash_esc}</code></p>
    <p>Fallback subscription URL:</p>
    <p><code>{sub_esc}</code></p>
  </div>
  <script>
    setTimeout(function () {{
      try {{ window.location.href = "{clash_esc}"; }} catch (e) {{}}
    }}, 80);
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "clash-bridge/1.0"

    def do_GET(self) -> None:
        u = urlparse(self.path)
        if u.path not in ("/", "/open"):
            self.send_error(HTTPStatus.NOT_FOUND, "Not Found")
            return

        q = parse_qs(u.query, keep_blank_values=True)
        sub_url = (q.get("sub", [""])[0] or q.get("url", [""])[0] or "").strip()
        if not _valid_sub_url(sub_url):
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid or missing sub/url parameter")
            return

        clash_link = _build_clash_link(sub_url)
        body = _html_page(sub_url, clash_link).encode("utf-8")

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format: str, *_args: object) -> None:
        return


def main() -> None:
    ap = argparse.ArgumentParser(description="HTTP bridge for Clash Verge deep-link.")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=25501)
    args = ap.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Listening on http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
