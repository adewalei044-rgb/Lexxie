# adewalei044-rgb
Just getting it done

## Lexxie - Debug Entry Signals (TradingView Pine Script)

`pinescript/Lexxie_Debug_Entry_Signals.pine` is a TradingView strategy built for
debugging entry signals on the 1-minute chart. It can take trades after any
combination of:

- **Engulfing candle** - a full-body reversal candle
- **Signal bar** - a rejection/pin bar following a prior directional move
- **Key bar** - a high-momentum breakout bar relative to ATR

### Install

1. Open TradingView -> Pine Editor -> New blank script.
2. Paste the contents of `pinescript/Lexxie_Debug_Entry_Signals.pine`.
3. Save and add it to a 1-minute chart.

### Settings (all editable in the indicator's Settings panel)

- **Entry Signal Types** - checkboxes to choose which pattern(s) (Engulfing /
  Signal Bar / Key Bar) are allowed to trigger trades, plus separate toggles
  for allowing longs and/or shorts.
- **Session Filter** - optional toggle to restrict entries to a chosen
  exchange-time session window (e.g. `0930-1130`), off by default.
- **Engulfing / Signal Bar / Key Bar Settings** - tunable thresholds (body
  ratio, wick ratio, ATR length/multiplier, close location, lookback) for
  each pattern.
- **Trade Management** - stop-loss type (ATR / Points / Percent), SL
  parameters, and reward:risk ratio for take-profit.
- **Debug Mode** - plots every raw pattern detected on the chart (even ones
  not enabled for trading) so you can visually validate signal logic, plus an
  optional warning if the chart isn't on the 1-minute timeframe.
- **Buy / Sell Entry Labels** - toggle and color the BUY/SELL labels drawn at
  each entry.
- **Stats Table** - toggle, position (defaults to top-right), and text size
  for the on-chart performance table.
- **Webhook / Alerts** - toggle to fire an `alert()` call on every entry (see
  Webhook automation below).

### On-chart output

- **BUY / SELL labels** at each entry, tagged with which pattern(s) fired.
- **Stats table** (top-right corner by default) showing: Win Rate, Wins,
  Losses, Daily Win, Daily Loss, and Drawdown.

### No repainting

The script is built so signals never repaint, while the stats table still
updates live:

- `calc_on_every_tick = true` lets the script recalculate on every price
  tick, so the table and plots stay live instead of freezing until a bar
  closes.
- `process_orders_on_close = true` keeps order fills realistic (priced off
  the bar's close, not an intrabar tick).
- Every pattern check, debug plot, and trade condition is separately gated
  on `barstate.isconfirmed`, so no signal, order, or marker is ever
  evaluated, drawn, or traded off a still-forming realtime bar. A BUY/SELL
  label or debug marker only appears once, on a confirmed close, and never
  shifts or vanishes afterward.

### Suggested starting settings

The defaults are tuned as a reasonable starting point for reducing false
signals on the noisy 1-minute timeframe (Engulfing + Key Bar enabled,
Signal Bar off, tighter pattern thresholds, ATR stop x1.1, Risk:Reward
1:1.5). This is **not a guaranteed winning configuration** - backtest it on
your actual symbol in TradingView's Strategy Tester and adjust from there.
Win rate alone doesn't imply profitability; watch the equity curve and
drawdown together with it. The Session Filter (off by default) is often the
single biggest lever for 1-minute signal quality - try restricting to your
market's most liquid hours before over-tuning the pattern thresholds.

### Webhook automation

Pine Script cannot open a network connection or POST to a URL by itself -
that part is always done by TradingView's own Alert engine, not by the
script. What the script *can* do is hand TradingView a ready-to-send
payload:

- Every `strategy.entry()`/`strategy.exit()` call sets `alert_message` to a
  JSON payload (symbol, action, price, stop, target, pattern, time).
- Turning on **Fire alert() on entries** (Webhook / Alerts group) also calls
  `alert()` directly on each entry with that same JSON.

To actually deliver it to your bot/bridge:

1. On the chart, click **Alert** -> create a new alert on this script.
2. Set **Condition** to either:
   - `Order fills` (recommended - covers entries and exits, uses the
     `alert_message` set on each order), or
   - `Any alert() function call` (fires only on entries, requires the
     **Fire alert() on entries** setting to be on).
3. Under **Notifications**, enable **Webhook URL** and paste your endpoint
   (e.g. a broker bridge, Zapier, or your own server).
4. Save. TradingView will POST the JSON message body to that URL whenever
   the alert fires.

Two ready-made relays that turn this JSON into real orders live in this
repo:

- [`webhook-relay/`](webhook-relay/) - crypto exchanges (Bybit, Bitget),
  runs on a cheap Linux VPS.
- [`mt5-relay/`](mt5-relay/) - MetaTrader 5 brokers (Exness and others),
  runs on a Windows VPS alongside the MT5 terminal.
