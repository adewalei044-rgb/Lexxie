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

### On-chart output

- **BUY / SELL labels** at each entry, tagged with which pattern(s) fired.
- **Stats table** (top-right corner by default) showing: Win Rate, Wins,
  Losses, Daily Win, Daily Loss, and Drawdown.
