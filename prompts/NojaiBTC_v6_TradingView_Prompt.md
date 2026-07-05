# NojaiBTC v6 — TradingView Pine Script Build Prompt

Use this as the build spec (or hand it directly to an AI coding assistant) to
implement/regenerate the **NojaiBTC** indicator, version 6, exactly as
configured in the reference screenshots. It supersedes the earlier
"Nojai Debug Entries" and "NOJAI 3" experimental layers — v6 consolidates
their settings into one clean input set.

## Objective

Build a TradingView Pine Script (v6) `indicator()` named **NojaiBTC**,
`overlay = true`, that:

0. **Must be bidirectional**: capable of generating and managing both BUY
   (long) and SELL (short) trades — not one-sided. Every entry, exit,
   SL/TP, and dashboard element below applies symmetrically to both trade
   directions (mirror the long-side math for shorts).
1. Generates BUY/SELL signals from a channel-breakout entry filtered by an
   EMA trend and a sensitivity/buffer setting.
2. Manages exits via market-structure pivots, an ATR trailing stop, and two
   risk-reward take-profit targets.
3. Draws entry/SL/TP lines and labels directly on the chart.
4. Optionally recolors bars using an RSI gradient.
5. Tracks simulated P&L (win/loss counts and $ P&L) daily/weekly/monthly/
   all-time and renders it in a live on-chart performance dashboard
   ("JMHP ENHANCED").
6. Fires alerts on signal/TP/SL/exit events.

## Inputs — group and order exactly as below

### General
| Input | Type | Default |
|---|---|---|
| Sensitivity | int | 4 |
| Entry Channel Length | int | 15 |
| Structure Exit Lookback | int | 14 |
| Show Exit Labels? | bool | false |
| TP Multiplier | float | 1 |
| ATR Period (for trailing stop) | int | 10 |
| Structure Pivot Length | int | 5 |
| Buffer % (e.g. 0.007 = 0.7%) | float | 0.001 |
| Show Entry Channels? | bool | false |
| Show TP/SL Lines? | bool | true |
| Exit on UT Trailing Stop? | bool | false |
| EMA Period | int | 200 |
| Show Dashboard? | bool | true |

### Visuals
| Input | Type | Default |
|---|---|---|
| Enable RSI Gradient Bars | bool | false |
| Enable Buy/Sell Labels | bool | true |

### Alerts
| Input | Type | Default |
|---|---|---|
| Enable Alerts | bool | true |

### Extras
| Input | Type | Default |
|---|---|---|
| Enable Peak Profit Tracker | bool | true |

### Risk Management
| Input | Type | Default |
|---|---|---|
| Risk Reward Ratio 1 | float | 1 |
| Risk Reward Ratio 2 | float | 2 |
| Line Length | int | 60 |
| Swing Detection Length | int | 10 |
| Max Risk % per trade | float | 0.1 |
| Enable Break-Even at TP1 | bool | false |

### P&L Tracking
| Input | Type | Default |
|---|---|---|
| Base Amount ($) | float | 100 |
| Lot Size | float | 0.05 |
| RSI Length | int | 14 |
| Title Text Color | color | gold/yellow |
| Title Background | color | transparent |
| Buy Text Color | color | green |
| Sell Text Color | color | red |
| Dashboard Background | color | transparent |

## Style tab

- **Buy Signal**: on, green marker (up arrow), plotted **below bar**.
- **Sell Signal**: on, red marker (down arrow), plotted **above bar**.
- **EMA**: on, orange line, basic line style.
- **Graphic objects**: Pane labels, Lines, Tables — all enabled.
- **Output values**: Precision = Default; Labels on price scale = on;
  Values in status line = on.
- **Input values**: Inputs in status line = on.

## Visibility tab

Enable on every resolution: Ticks, Seconds (1–59), Minutes (1–59),
Hours (1–24), Days (1–366), Weeks (1–52), Months (1–12), Ranges.

## Chart drawing elements — exactly as shown in the reference screenshot

These are transcribed directly from the live chart image (not inferred):

- **SELL label**: solid red rounded tag with the word "SELL", placed directly
  above the signal candle.
- **SL line**: red dotted horizontal line extending right from the signal,
  with a red flag tag reading `"SL: 62319.5"`.
- **Entry line**: solid black/dark horizontal line extending right from the
  signal, with a red flag tag reading `"SELL: 62048.5"`.
- **TP1 line**: blue dotted horizontal line extending right, with a blue tag
  reading `"TP1: 61777.5"` and a green checkmark next to it (indicating that
  level was reached).
- **TP2 line**: blue dotted horizontal line extending right, with a blue tag
  reading `"TP2: 61506.5"` (no checkmark — not yet reached).
- **EMA line**: an orange/tan line running through price, with several small
  hollow circle markers sitting on it at intervals.
- A separate floating text box, **not part of NojaiBTC**, reading
  "Institutional MACD Bias / Short Term: Look For Buy Only / Long Term: Look
  For Buy Only / Overall Bias: Look For Buy Only".

Only build the BUY label, SELL label, entry line, SL line, TP1 line, and TP2
line as literally shown above. Everything else below this point (channel
lines, RSI gradient bars, break-even, alerts, dashboard counters) should
follow the **Inputs** section, since those are the only toggles/values the
screenshots actually expose for them.

## Signal / trade logic — inferred from input names only (verify before building)

The screenshots show the **settings and outputs**, not the Pine Script source,
so the exact formulas below are a reasonable reading of the input labels, not
confirmed logic. Treat this section as a starting hypothesis to confirm with
whoever owns the original script, not as ground truth:

- **Entry channel**: some form of upper/lower breakout channel over
  `Entry Channel Length` bars, adjusted by `Sensitivity`, with `Buffer %`
  padding the channel bounds — implied by the "Entry Channel Length",
  "Sensitivity", and "Buffer %" input names and the (unchecked) "Show Entry
  Channels?" toggle.
- **Trend filter**: EMA(`EMA Period`) is plotted on the chart, so it is
  likely used as a directional filter, but the screenshots don't show how.
- **Structure exit**: `Structure Pivot Length` and `Structure Exit Lookback`
  imply a pivot-based structure exit, with `Show Exit Labels?` controlling
  whether exit markers are drawn — not otherwise confirmed.
- **Trailing stop**: `ATR Period (for trailing stop)` and `Exit on UT
  Trailing Stop?` imply an ATR-based trailing stop that can optionally force
  an exit — not otherwise confirmed.
- **Take profit**: `Risk Reward Ratio 1` / `Risk Reward Ratio 2` and
  `TP Multiplier` imply TP1/TP2 are risk-multiples of the stop distance,
  consistent with the two TP lines seen on the chart — not otherwise
  confirmed.
- **Break-even**: `Enable Break-Even at TP1` implies the stop moves to entry
  once TP1 is hit — not otherwise confirmed.
- **Position sizing**: `Max Risk % per trade`, `Base Amount ($)`, and
  `Lot Size` imply the dashboard's $ P&L figures are derived from these —
  not otherwise confirmed.

## Dashboard ("JMHP ENHANCED" performance table)

Top-right table, rendered only when `Show Dashboard?` is true. Two columns
(label | value), rows and background colors as below.

**Must display on time**: the table is drawn/updated on every realtime tick
(`barstate.islast`), not only on bar close, so it never shows stale values —
`Status`, `Current Signal`, `Entry Time`, and every P&L/win-loss figure must
reflect the current bar the instant it changes, with no lag behind price.

| Row | Sample value | Background |
|---|---|---|
| Header row: "JMHP ENHANCED" / "Performance" | — | black/dark header |
| Total Wins | 121 | green |
| Total Losses | 38 | red |
| Total Win % | 76.1% | gray |
| Daily Wins | 10 | blue |
| Daily Losses | 1 | maroon |
| Daily Win % | 90.91% | dark navy |
| Weekly Wins | 62 | orange |
| Weekly Losses | 13 | magenta |
| Weekly Win % | 82.67% | green |
| Month Wins | 49 | olive |
| Month Losses | 11 | purple |
| Monthly Win % | 81.67% | teal |
| Status | e.g. "NO TRADE" / "LONG ACTIVE" / "SHORT ACTIVE" | gray |
| Current Signal | "BUY" / "SELL" / "None" | gray |
| Entry Time | UTC timestamp or "None" | teal |
| Week P&L $ | +24.6 | green if ≥ 0, red if < 0 |
| Month P&L $ | +96.03 | green if ≥ 0, red if < 0 |
| Total P&L $ | -89.61 | green if ≥ 0, red if < 0 |
| Break-Evens | "0 (W0/M0)" | tan/yellow |

Counters accumulate wins/losses/P&L per day, week, month, and all-time using
`Base Amount ($)` / `Lot Size` for the $ figures, resetting the daily/weekly/
monthly buckets at session/week/month boundaries. `Status`, `Current Signal`,
and `Entry Time` reflect the live open position (or "NO TRADE" / "None" when
flat). The optional **Peak Profit Tracker** (`Enable Peak Profit Tracker`)
records the best unrealized P&L reached during each open trade for later
reporting.

## Alerts

When `Enable Alerts` is on, define `alertcondition()`s for: new BUY signal,
new SELL signal, TP1 hit, TP2 hit, SL hit, structure-exit trigger, and
UT-trailing-stop exit (if `Exit on UT Trailing Stop?` is enabled).

## Out of scope for v6

- The "Institutional MACD Bias" panel (Short Term / Long Term / Overall
  Bias: "Look For Buy Only") seen on the reference chart is a **separate**
  indicator, not part of NojaiBTC. Do not merge its logic in unless
  explicitly asked.
- "Nojai Debug Entries" and "NOJAI 3" are prior experimental scripts;
  v6 replaces them — do not port their leftover inputs verbatim, only the
  consolidated set documented above.
