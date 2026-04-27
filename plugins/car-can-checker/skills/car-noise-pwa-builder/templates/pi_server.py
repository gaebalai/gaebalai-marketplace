#!/usr/bin/env python3
"""{{PROJECT_NAME}} — Pi 4 aiohttp HTTPS + WebSocket + python-can decoder.

USB-CAN 어댑터 → socketcan(can0) → 디코딩 → WebSocket 브로드캐스트.
신호 매핑은 SIGNAL_MAPPING으로 하드코딩되어 있다 (스킬 생성 시 치환됨).
"""
from __future__ import annotations

import asyncio
import json
import ssl
import time
from pathlib import Path

import can
from aiohttp import WSMsgType, web

ROOT = Path(__file__).parent
PWA_DIR = ROOT.parent / "pwa"

SIGNAL_MAPPING = {{SIGNAL_MAPPING_JSON}}

CAN_CHANNEL = "can0"
CAN_BITRATE = 500_000

clients: set[web.WebSocketResponse] = set()


def decode(data: bytes, byte: int, width: int, endian: str, scale: float, offset: float) -> float | None:
    if width == 8:
        if byte >= len(data):
            return None
        v = data[byte]
    else:
        if byte + 1 >= len(data):
            return None
        if endian.startswith("big"):
            v = (data[byte] << 8) | data[byte + 1]
        else:
            v = (data[byte + 1] << 8) | data[byte]
        if endian.endswith("signed") and v & 0x8000:
            v -= 0x10000
    return v * scale + offset


def build_index() -> dict[int, list[tuple[str, dict]]]:
    idx: dict[int, list[tuple[str, dict]]] = {}
    for name, m in SIGNAL_MAPPING.items():
        cid = int(m["id"], 0)
        idx.setdefault(cid, []).append((name, m))
    return idx


async def can_loop():
    idx = build_index()
    bus = can.Bus(channel=CAN_CHANNEL, interface="socketcan", bitrate=CAN_BITRATE)
    loop = asyncio.get_event_loop()
    reader = can.AsyncBufferedReader()
    notifier = can.Notifier(bus, [reader], loop=loop)
    try:
        async for msg in reader:
            if msg.arbitration_id not in idx:
                continue
            payload = {"t": time.time()}
            for name, m in idx[msg.arbitration_id]:
                v = decode(bytes(msg.data), m["byte"], m["width"], m["endian"], m["scale"], m["offset"])
                if v is not None:
                    payload[name] = v
            if len(payload) == 1:
                continue
            txt = json.dumps(payload)
            dead = []
            for ws in clients:
                try:
                    await ws.send_str(txt)
                except ConnectionResetError:
                    dead.append(ws)
            for ws in dead:
                clients.discard(ws)
    finally:
        notifier.stop()
        bus.shutdown()


async def ws_handler(request: web.Request):
    ws = web.WebSocketResponse(heartbeat=15)
    await ws.prepare(request)
    clients.add(ws)
    try:
        async for msg in ws:
            if msg.type == WSMsgType.ERROR:
                break
    finally:
        clients.discard(ws)
    return ws


async def index(_):
    return web.FileResponse(PWA_DIR / "index.html")


async def on_startup(app):
    app["can_task"] = asyncio.create_task(can_loop())


async def on_cleanup(app):
    app["can_task"].cancel()


def make_app() -> web.Application:
    app = web.Application()
    app.router.add_get("/", index)
    app.router.add_get("/ws", ws_handler)
    app.router.add_static("/", PWA_DIR, show_index=False)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    return app


def main():
    cert = ROOT / "certs" / "cert.pem"
    key = ROOT / "certs" / "key.pem"
    ssl_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ssl_ctx.load_cert_chain(cert, key)
    web.run_app(make_app(), host="0.0.0.0", port=8443, ssl_context=ssl_ctx)


if __name__ == "__main__":
    main()
