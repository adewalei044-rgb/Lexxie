# NojaiBTC v6 — TradingView Settings

Indicator name: **NojaiBTC**

Must support both BUY and SELL signals (bidirectional — long and short).
Must not repaint (signals/labels/lines lock in on closed bars only).
Dashboard must update live, on time, with no lag.

## Inputs

**General**
- Sensitivity: 4
- Entry Channel Length: 15
- Structure Exit Lookback: 14
- Show Exit Labels?: unchecked
- TP Multiplier: 1
- ATR Period (for trailing stop): 10
- Structure Pivot Length: 5
- Buffer % (e.g. 0.007 = 0.7%): 0.001
- Show Entry Channels?: unchecked
- Show TP/SL Lines?: checked
- Exit on UT Trailing Stop?: unchecked
- EMA Period: 200
- Show Dashboard?: checked

**Visuals**
- Enable RSI Gradient Bars: unchecked
- Enable Buy/Sell Labels: checked

**Alerts**
- Enable Alerts: checked

**Extras**
- Enable Peak Profit Tracker: checked

**Risk Management**
- Risk Reward Ratio 1: 1
- Risk Reward Ratio 2: 2
- Line Length: 60
- Swing Detection Length: 10
- Max Risk % per trade: 0.1
- Enable Break-Even at TP1: unchecked

**P&L Tracking**
- Base Amount ($): 100
- Lot Size: 0.05
- RSI Length: 14
- Title Text Color: gold/yellow
- Title Background: transparent
- Buy Text Color: green
- Sell Text Color: red
- Dashboard Background: transparent

## Style

- Buy Signal: on, green, up arrow, Below bar
- Sell Signal: on, red, down arrow, Above bar
- EMA: on, orange line
- Pane labels: on
- Lines: on
- Tables: on
- Labels on price scale: on
- Values in status line: on
- Inputs in status line: on

## Visibility

All enabled: Ticks, Seconds (1–59), Minutes (1–59), Hours (1–24), Days (1–366), Weeks (1–52), Months (1–12), Ranges

## Chart elements

- BUY label: green tag, up arrow, "BUY", below bar
- SELL label: red tag, down arrow, "SELL", above bar
- Entry line: solid dark line, tag "BUY: <price>" / "SELL: <price>"
- SL line: red dotted line, tag "SL: <price>"
- TP1 line: blue dotted line, tag "TP1: <price>"
- TP2 line: blue dotted line, tag "TP2: <price>"
- EMA line: orange line over price

## Dashboard — JMHP ENHANCED

| Row | Value | Color |
|---|---|---|
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
| Status | NO TRADE | gray |
| Current Signal | None | gray |
| Entry Time | None | teal |
| Week P&L $ | +24.6 | green |
| Month P&L $ | +96.03 | green |
| Total P&L $ | -89.61 | red |
| Break-Evens | 0 (W0/M0) | tan |
