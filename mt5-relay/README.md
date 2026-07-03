# Lexxie MT5 Relay (Exness and other MetaTrader 5 brokers)

Receives the same webhook JSON as `../webhook-relay/` (the crypto relay) and
places the matching order through a **locally-running MetaTrader 5
terminal**, using the official `MetaTrader5` Python package.

## Why this is a separate project from the crypto relay

Bybit/Bitget expose a public REST API you can call from anywhere. MT5
doesn't - the `MetaTrader5` Python package talks to the terminal over local
IPC, so this script **must run on the same machine as the MT5 terminal**,
and that terminal only runs on **Windows** (or Wine, which is fragile - not
recommended). This means:

- Your crypto trading (Bybit/Bitget) can stay on the cheap Linux VPS from
  `../webhook-relay/`.
- Exness (or any other MT5 broker) needs its **own Windows VPS** with the
  MT5 terminal installed, logged into your account, and this script running
  alongside it.

Both relays accept the exact same webhook JSON from the Lexxie script, so
you just point TradingView's alert at whichever relay's URL matches the
symbol you're trading (or run both and use two alerts with different
symbols/webhook URLs).

## Setup (Windows VPS)

1. Get a Windows VPS (most VPS providers offer Windows Server images;
   pick a region close to your broker's servers).
2. Remote into it (Windows has Remote Desktop built in - your phone needs a
   free RDP client app, e.g. "Microsoft Remote Desktop" or "RD Client").
3. Install the MT5 terminal for your broker (Exness provides their own MT5
   installer from their website) and log into your trading account. Leave
   the terminal running.
4. Install Python 3.10+ from python.org (check "Add to PATH" during
   install).
5. Open Command Prompt / PowerShell and run:

   ```
   cd path\to\Lexxie\mt5-relay
   pip install -r requirements.txt
   copy .env.example .env
   notepad .env
   ```

6. Fill in `.env`:
   - `WEBHOOK_SECRET` - a long random string.
   - Leave `MT5_LOGIN`/`MT5_PASSWORD`/`MT5_SERVER` blank if the terminal is
     already logged in (simplest) - the script will just use that session.
   - `SYMBOL_SUFFIX` - check your MT5 Market Watch for how your broker names
     symbols (e.g. `XAUUSDm` instead of `XAUUSD`) and set the suffix here.
   - Choose `RISK_MONEY` or `FIXED_LOT` for position sizing.
7. Run it:

   ```
   python app.py
   ```

   You should see "Connected to MT5 account #..." in the console. Keep this
   window open (or set it up as a Windows service/scheduled task to survive
   reboots - see below).
8. Expose it to the internet so TradingView can reach it: either
   - Put it behind a reverse proxy + HTTPS (IIS, Caddy, or Nginx for
     Windows) and open port 443 in the Windows Firewall, or
   - Use a tunnel service (e.g. Cloudflare Tunnel, ngrok) if you don't want
     to manage a public IP/cert on Windows - the tunnel gives you an HTTPS
     URL that forwards to `127.0.0.1:3001`.
9. In TradingView, create an alert on the Lexxie script (**Condition: Order
   fills**) with the Webhook URL set to:

   ```
   https://YOUR_TUNNEL_OR_DOMAIN/hook/<your WEBHOOK_SECRET>
   ```

10. Test on a **demo account** first (Exness and most MT5 brokers let you
    open a demo account instantly) before pointing this at a funded live
    account.

## Running it as a background service

The simplest option on Windows: **Task Scheduler** -> Create Task -> Trigger
"At startup" -> Action "Start a program" -> `python.exe` with argument
`C:\path\to\mt5-relay\app.py` and "Start in" set to the `mt5-relay` folder.
Check "Run whether user is logged on or not" so it survives disconnecting
your RDP session.

## How it works

- TradingView POSTs the JSON `alert_message` the Lexxie strategy already
  builds (`buy` / `sell` / `close_long` / `close_short`, with symbol, price,
  stop, target) to `/hook/<secret>`.
- The relay maps the TradingView symbol to your broker's MT5 symbol name
  (via `SYMBOL_SUFFIX`), computes a lot size, and sends a market order via
  `mt5.order_send()` with the stop-loss/take-profit attached directly to
  the order.
- Closing (`close_long`/`close_short`) looks up the open position on that
  symbol and sends an opposite-direction order tagged with the position's
  ticket, which MT5 treats as a close.

## Notes / limitations

- `type_filling` is set to `IOC` in the order request - some brokers only
  accept `FOK` or `RETURN` for certain symbols. If orders get rejected with
  a filling-mode error, edit `send_market_order()` in `app.py` and try
  `mt5.ORDER_FILLING_FOK` or `mt5.ORDER_FILLING_RETURN` instead.
- Risk-based lot sizing (`RISK_MONEY`) uses the symbol's tick value/size
  from MT5, which is generally accurate for forex and commodity CFDs. Sanity
  check the resulting lot size against your broker's margin calculator
  before trusting it with real funds.
- Not tested against a live MT5 terminal in this environment (Linux sandbox,
  and MT5 is Windows-only) - review the code and test thoroughly on a demo
  account before going live.

## Security notes

- Never commit `.env` - it can hold your MT5 login credentials.
- Keep the webhook secret long and random.
- If exposing this directly to the internet (not via a tunnel service),
  put it behind HTTPS - don't send the webhook secret over plain HTTP.
