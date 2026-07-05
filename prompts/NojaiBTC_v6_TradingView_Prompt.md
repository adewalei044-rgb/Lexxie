# NojaiBTC v6 — TradingView Pine Script Build Prompt

Use this as the build spec (or hand it directly to an AI coding assistant) to
implement/regenerate the **NojaiBTC** indicator, version 6, exactly as
configured in the reference screenshots. It supersedes the earlier
"Lexxie Debug Entries" and "LEXXIE 3" experimental layers — v6 consolidates
their settings into one clean input set.

## Objective

Build a TradingView Pine Script (v6) `indicator()` named **NojaiBTC**,
`overlay = true`, that:

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

## Signal / trade logic

- **Entry channel**: Donchian-style upper/lower channel over
  `Entry Channel Length` bars, widened/tightened by `Sensitivity`.
  `Buffer %` is added to the upper bound and subtracted from the lower bound
  to reduce false breakouts.
- **Trend filter**: EMA(`EMA Period`). Only take BUY signals when price is
  above the EMA and the breakout is up; only take SELL signals when price is
  below the EMA and the breakout is down.
- **Structure exit**: detect pivot highs/lows with `Structure Pivot Length`;
  exit an open trade when price breaks the most recent opposing pivot within
  `Structure Exit Lookback` bars. Draw an exit label on the bar when
  `Show Exit Labels?` is enabled.
- **ATR trailing stop**: ATR(`ATR Period`) trailing stop (UT Bot style)
  plotted as a stepped line; when `Exit on UT Trailing Stop?` is enabled, a
  trailing-stop cross also force-closes the open trade.
- **Stop loss**: derived from the most recent swing high/low using
  `Swing Detection Length`, offset by `Buffer %`.
- **Take profit**: TP1 = entry ± initial risk × `Risk Reward Ratio 1` ×
  `TP Multiplier`; TP2 = entry ± initial risk × `Risk Reward Ratio 2` ×
  `TP Multiplier`.
- **Break-even**: if `Enable Break-Even at TP1` is on, move the stop to the
  entry price once TP1 is touched.
- **Position sizing**: use `Max Risk % per trade` against `Base Amount ($)`
  and `Lot Size` to compute the simulated $ P&L per closed trade for the
  dashboard.

## Chart drawing elements

- **BUY label**: green rounded tag, up-arrow icon, text "BUY", below the
  signal bar. Color from `Buy Text Color`.
- **SELL label**: red rounded tag, down-arrow icon, text "SELL", above the
  signal bar. Color from `Sell Text Color`.
- **Entry line**: solid dark line projected `Line Length` bars forward from
  the entry bar, tagged `"BUY: <price>"` or `"SELL: <price>"`.
- **SL line**: dotted red line, `Line Length` bars forward, tagged
  `"SL: <price>"`.
- **TP1 / TP2 lines**: dotted blue lines, `Line Length` bars forward, tagged
  `"TP1: <price>"` / `"TP2: <price>"`; append a green checkmark to the tag
  once that level is touched. Only drawn when `Show TP/SL Lines?` is on.
- **Entry channels**: optional upper/lower channel lines, only drawn when
  `Show Entry Channels?` is on.
- **EMA line**: orange plot of EMA(`EMA Period`) over price.
- **RSI gradient bars**: when `Enable RSI Gradient Bars` is on, recolor
  candle bodies on a gradient keyed off RSI(`RSI Length`) — cool color near
  oversold, warm color near overbought.

## Dashboard ("JMHP ENHANCED" performance table)

Top-right table, rendered only when `Show Dashboard?` is true. Two columns
(label | value), rows and background colors as below:

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
- "Lexxie Debug Entries" and "LEXXIE 3" are prior experimental scripts;
  v6 replaces them — do not port their leftover inputs verbatim, only the
  consolidated set documented above.
