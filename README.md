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

The script is built so signals never repaint:

- `calc_on_every_tick = false` and `process_orders_on_close = true` on the
  `strategy()` declaration mean the script only recalculates and places
  orders once a bar has actually closed, not on every intrabar price tick.
- Every pattern check, debug plot, and trade condition is additionally
  gated on `barstate.isconfirmed`, so nothing is evaluated, drawn, or traded
  off a still-forming realtime bar. A BUY/SELL label or debug marker only
  appears once, on a confirmed close, and never shifts or vanishes
  afterward.

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
