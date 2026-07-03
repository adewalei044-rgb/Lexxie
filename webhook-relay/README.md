# Lexxie Webhook Relay (crypto exchanges)

Small always-on server that receives TradingView webhook alerts from the
`Lexxie - Debug Entry Signals` strategy and places the matching order on a
crypto exchange. Runs on a small VPS; managed entirely from your phone.

Supports **Bybit** and **Bitget** today via a pluggable broker adapter -
adding another crypto exchange later is a small new file, no rewrite. For
**MT5-based brokers (Exness, and others)**, use the separate
[`../mt5-relay/`](../mt5-relay/) project instead - MT5 doesn't have a public
REST API this relay can call directly, so it needs to run alongside the
MetaTrader terminal itself.

## What you need first

- A VPS (Vultr, Tokyo region recommended for lowest latency to Bybit/Bitget).
- An SSH app on your phone (Termius is the standard free option).
- An API key on your chosen exchange with **Trade permission only** (no
  withdrawal), IP-whitelisted to your VPS's IP:
  - Bybit: API Management in account settings.
  - Bitget: API Management - note Bitget also requires a **passphrase** you
    set when creating the key, in addition to the key/secret.

## Setup (from your phone, via Termius)

1. SSH into your fresh Ubuntu 22.04 VPS as `root`.
2. Run the installer, pointing it at this repo's branch:

   ```
   curl -fsSL https://raw.githubusercontent.com/adewalei044-rgb/lexxie/claude/tradingview-debug-entry-signals-uy949p/webhook-relay/install.sh | bash -s -- claude/tradingview-debug-entry-signals-uy949p
   ```

   This installs Node.js, Nginx, creates a locked-down service user, pulls
   this code, installs dependencies, sets up a systemd service, and enables
   a firewall (SSH/HTTP/HTTPS only). It prints the exact next steps at the
   end - follow them:

3. Edit `/opt/lexxie-relay/.env` (`nano /opt/lexxie-relay/.env`) and fill in:
   - `WEBHOOK_SECRET` - generate with `openssl rand -hex 24`.
   - `BROKER` - `bybit` or `bitget`.
   - That broker's API key/secret (and passphrase, for Bitget).
   - Leave the testnet/demo flag on until you've confirmed everything works.
   - Choose position sizing: either `RISK_USDT` (risk a fixed $ amount per
     trade, sized off the entry/stop distance Lexxie sends) or `FIXED_QTY`
     (always trade the same size). Set `QTY_STEP` to match your symbol's
     minimum order increment on that exchange.
4. `systemctl start lexxie-relay` then `systemctl status lexxie-relay` to
   confirm it's running, and `journalctl -u lexxie-relay -f` to watch logs.
5. (Recommended) Put it behind HTTPS with Nginx + Let's Encrypt - the
   installer prints the exact commands.
6. In TradingView, create an alert on the Lexxie script with **Condition:
   Order fills** (covers entries and exits) and set the **Webhook URL**
   under Notifications to:

   ```
   https://YOUR_DOMAIN/hook/<your WEBHOOK_SECRET>
   ```

7. Test on the testnet/demo environment with tiny size first. Only flip to
   live trading (real API keys with real funds) once you've watched several
   test trades land correctly.

## Running Bybit and Bitget at the same time

Each relay process serves exactly one `BROKER`. To trade both exchanges from
one Lexxie chart, run two copies of this relay on the same VPS (different
`PORT` and `.env` per copy, e.g. `/opt/lexxie-relay-bybit` and
`/opt/lexxie-relay-bitget`, each with its own systemd unit and Nginx
location block), and create two separate TradingView alerts with different
webhook URLs/secrets pointing at each.

## How it works

- TradingView POSTs the JSON `alert_message` your Lexxie strategy already
  builds on every entry/exit (`buy` / `sell` / `close_long` / `close_short`)
  to `/hook/<secret>`.
- The relay checks the secret in the URL path, parses the JSON, and calls
  the active broker's API: a `Market` order to open, and a `reduceOnly`
  (Bybit) / `close`-side (Bitget) `Market` order sized to the current open
  position to close.
- No Pine Script changes are needed - the secret lives only in the
  TradingView alert's Webhook URL field, not in the script itself.

## Files

- `server.js` - the relay's HTTP server and webhook handler (broker-agnostic).
- `brokers/index.js` - picks the active adapter from the `BROKER` env var.
- `brokers/bybit.js` - Bybit v5 request signing and order/position calls.
- `brokers/bitget.js` - Bitget v2 request signing and order/position calls.
- `install.sh` - one-shot VPS setup script (see above).
- `lexxie-relay.service` - systemd unit so the relay survives reboots/crashes.
- `nginx.conf.template` - reverse proxy config for HTTPS via Nginx.
- `.env.example` - all configuration options, copy to `.env` and fill in.

## Adding another crypto exchange

Drop a new file in `brokers/` exporting the same two functions as
`brokers/bybit.js` (`placeMarketOrder` and `getOpenPositionQty`), register it
in `brokers/index.js`, and add its config to `.env.example`. `server.js`
needs no changes.

## Security notes

- Never commit `.env` - it holds your live API secret(s).
- Use an API key scoped to **Trade only**, never withdrawal.
- IP-whitelist the key to your VPS's IP.
- Keep the webhook secret long and random; anyone with the URL can trigger
  trades on your account.
