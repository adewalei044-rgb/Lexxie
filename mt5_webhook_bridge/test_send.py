"""Fires sample TradingView-style payloads at a running bridge for testing.

Usage: python test_send.py [base_url] [secret]
Defaults to http://127.0.0.1:5000 and the WEBHOOK_SECRET in your .env.
"""
import sys
import time

import requests

import config

base_url = sys.argv[1] if len(sys.argv) > 1 else f"http://127.0.0.1:{config.PORT}"
secret = sys.argv[2] if len(sys.argv) > 2 else config.WEBHOOK_SECRET

samples = [
    {"action": "buy", "symbol": "EURUSD", "side": "long", "price": 1.0855,
     "sl": 1.0830, "tp": 1.0900, "qty": 1, "strategy": "ICT-MTF-Confluence",
     "time": "2026-06-28T10:15:00Z"},
    {"action": "close", "symbol": "EURUSD", "side": "long",
     "strategy": "ICT-MTF-Confluence"},
    {"action": "sell", "symbol": "XAUUSD", "side": "short", "price": 2350.5,
     "sl": 2360.0, "tp": 2330.0, "qty": 0.5, "strategy": "London-Asian-Breakout",
     "time": "2026-06-28T07:05:00Z"},
]

for payload in samples:
    resp = requests.post(
        f"{base_url}/webhook",
        json=payload,
        headers={"X-Webhook-Secret": secret},
        timeout=10,
    )
    print(payload["action"], payload["symbol"], "->", resp.status_code, resp.json())
    time.sleep(0.5)
