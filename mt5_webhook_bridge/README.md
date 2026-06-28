# TradingView Webhook -> MT5 Auto-Trade Bridge

Receives the `alert_message` JSON that the four Pine scripts in
`../tradingview/` already build (e.g. `{"action":"buy","symbol":"EURUSD",
"side":"long","price":1.0855,"sl":1.0830,"tp":1.0900,"qty":1,
"strategy":"ICT-MTF-Confluence","time":"..."}`) and places/closes the
matching order in MetaTrader 5 via the official `MetaTrader5` Python package.

**This code has not been run against a real MT5 terminal or broker
connection** — I have no live trading environment in this sandbox to test
against. Treat it as a solid starting point that needs a supervised dry-run
and then a demo-account run before you trust it with real money.

## How it fits together

```
TradingView alert  --POST-->  app.py (Flask)  -->  mt5_bridge.py  -->  MetaTrader5 package  -->  MT5 terminal (must be open + logged in)
```

The `MetaTrader5` Python package only talks to a **locally running, logged-in
MT5 terminal on the same machine** — it cannot connect to your broker over
the network by itself, and it only exists on Windows (no Linux/Mac terminal
build). So this bridge needs to run on the same Windows box as your MT5
terminal — your own PC, or a cheap Windows VPS.

## Setup

1. Install MT5, log into your account in the terminal, and leave it running.
2. On that same machine:
   ```
   pip install -r requirements.txt
   copy .env.example .env
   ```
3. Edit `.env`:
   - `MT5_LOGIN` / `MT5_PASSWORD` / `MT5_SERVER` — your account credentials.
   - `WEBHOOK_SECRET` — a long random string. TradingView has no built-in
     webhook auth, so this is the only thing stopping a stranger who finds
     your URL from sending fake trade signals.
   - `SYMBOL_MAP` — many brokers suffix symbols (`EURUSD.a`, `XAUUSDm`, etc).
     Map whatever each script's `webhookSymbol` input sends to the exact
     name your broker uses in MT5's Market Watch.
   - Leave `DRY_RUN=true` for now.
4. Run it:
   ```
   python app.py
   ```
5. Test it without touching MT5 at all:
   ```
   python test_send.py
   ```
   Check `webhook_bridge.log` — you should see `[DRY_RUN] would open ...` /
   `would close ...` lines matching exactly what you sent. This is the step
   to repeat after any change before going further.
6. When the dry-run log looks right, switch your MT5 terminal to a **demo
   account**, set `DRY_RUN=false`, restart `app.py`, and re-run
   `test_send.py` (or fire a real alert from a paper-trading chart) to watch
   real (demo) orders land in the terminal.
7. Only after that succeeds repeatedly should you point `MT5_LOGIN` at a live
   account.

## Wiring up TradingView

For each of the four strategies, in the chart's **Alert** dialog:

1. Condition: the strategy, trigger on **"Order fills"**.
2. Check **Webhook URL**, set it to:
   ```
   https://<your-public-address>/webhook?secret=<WEBHOOK_SECRET>
   ```
   (or omit the query param and instead have your reverse proxy inject the
   `X-Webhook-Secret` header — query param is simpler to set up first.)

TradingView's servers need to reach this URL over the public internet, but
your Windows box probably isn't directly reachable. Practical options, easiest
first:
- **Cloudflare Tunnel** or **ngrok** running alongside `app.py` on the same
  machine — gives you a public HTTPS URL pointed at your local port, no
  router/firewall changes needed. Good for getting started; review their
  pricing/limits for anything beyond casual use.
- A small Windows VPS with a real domain + TLS cert (e.g. via Caddy or
  nginx as a reverse proxy in front of `waitress-serve app:app`) if you want
  something more permanent.

Either way, terminate TLS in front of this app — don't expose the Flask/
waitress port directly with plain HTTP, since the webhook secret would
otherwise travel in cleartext.

## Payload contract

```json
{
  "action": "buy" | "sell" | "close",
  "symbol": "EURUSD",
  "side": "long" | "short",
  "price": 1.0855,
  "sl": 1.0830,
  "tp": 1.0900,
  "qty": 1,
  "strategy": "ICT-MTF-Confluence",
  "time": "2026-06-28T10:15:00Z"
}
```

- `qty` is sent straight through as the MT5 **lot size** — it's the raw value
  of each Pine script's `qtyForAlert` input, not derived from the strategy's
  backtest position sizing. Set that input in each script to the lot size you
  actually want traded; the bridge does not rescale it (it only clamps it to
  `MAX_LOT_SIZE` as a sanity backstop).
- `close` closes every open position on that symbol whose MT5 magic number
  matches the strategy (see `config.STRATEGY_MAGIC`) — it never touches
  positions you opened manually in the terminal, or positions from a
  different strategy on the same symbol.
- Each strategy gets its own fixed magic number (100001-100004 in
  `config.py`) so the four scripts' positions never get closed by each
  other's signals.

## Safety notes

- `DRY_RUN=true` is the default and logs every action instead of sending it —
  treat flipping it to `false` as a deliberate, reviewed decision, not a
  default state.
- The webhook endpoint has no auth at all if `WEBHOOK_SECRET` is left blank;
  the app only tolerates that in `DRY_RUN` mode and rejects every request
  with a blank secret once `DRY_RUN=false`.
- `MAX_LOT_SIZE` is a hard backstop against a malformed/garbled `qty` value
  blowing up your position size — tune it to something you'd accept even in
  the worst case.
- This places real orders with real money once `DRY_RUN=false` and pointed at
  a live account. Automated trading carries real risk of loss independent of
  any bug in this code — the strategies' own backtested win rate is not a
  guarantee of future performance.
