# adewalei044-rgb
Just getting it done

## TrendFocus Multi-Strategy (MT4)

A port of a 4-strategy Pine Script system (Sweep Reversal, Trend
Continuation, RSI Divergence, Bollinger Bands) to MetaTrader 4, split into
two files that share one signal engine:

- `MQL4/Include/TrendFocusCore.mqh` -- signal-detection logic only (no
  chart objects, no orders). Both files below include this.
- `MQL4/Indicators/TrendFocus_MultiStrategy.mq4` -- draws sweep/continuation
  boxes, OB/FVG zones, BUY/SELL labels, SL/TP lines, and an info panel.
  Fires MT4 alerts/push notifications on signals. **Places no trades.**
- `MQL4/Experts/TrendFocus_MultiStrategy_EA.mq4` -- runs the same signal
  engine and places real orders, with risk-based position sizing,
  break-even management, max daily loss cutoff, max open trades, max
  trades/day, session filter, and spread guard.

### Install

1. Copy `TrendFocusCore.mqh` into your terminal's `MQL4/Include/` folder.
2. Copy the indicator into `MQL4/Indicators/` and the EA into
   `MQL4/Experts/`.
3. Open MetaEditor, open each `.mq4` file, and compile (F7). Fix any
   compiler errors reported (this was written without access to a MetaEditor
   compiler, so please report back the exact error text if compilation
   fails and it can be corrected).
4. Restart MT4 (or right-click Navigator > Refresh) so both show up under
   Indicators / Expert Advisors.
5. Attach the indicator and/or the EA to a chart of the symbol you want to
   trade. Both read their own Inputs tab -- see below.

Run **both** on the same chart for visuals + execution together, or just
the indicator for a signal-only view, or just the EA to trade headless.

### Inputs tab (both files)

- **Strategy Toggles** -- enable/disable each of the 4 strategies.
- **Strategy 1-4 groups** -- per-strategy timeframe pairs, detection
  method, OB/FVG toggles, max-wait-bars, one-signal-per-setup.
- **Signal SL/TP** -- Risk:Reward multiple, Structural vs Fixed % SL/TP,
  break-even trigger.
- **Session Filter** -- optional trading-window restriction (London / New
  York / Asian / Overlap / Custom), with a broker GMT-offset input since
  MT4 has no built-in timezone conversion.

### EA-only: Risk Management tab

- **Position sizing**: Fixed Lots, Fixed Money (approximate notional), or
  **Risk % of Equity** (recommended -- sizes off the real SL distance, so
  every trade risks the same dollar amount regardless of stop width).
- **Max Daily Loss %** -- halts new entries for the rest of the day if
  equity drawdown exceeds this from the day's starting equity.
- **Max Open Trades** -- concurrent cap across all 6 pair-instances
  (mirrors the source script's `pyramiding=6`).
- **Max Trades/Day**, **Max Spread**, **Slippage**, **Magic Number base**.
- **Webhook Alerts** (optional) -- posts a JSON payload via `WebRequest()`
  on fill/break-even; the target URL must be whitelisted under
  *Tools > Options > Expert Advisors > Allow WebRequest for listed URL*.

### Notes / known limitations

- Written without a MetaEditor compiler available in this environment --
  it has not been compiled or backtested. Please compile first and report
  any errors.
- "Auto (Structure)" trend detection (Strategy 2) is a simplified
  higher/lower-close proxy, matching the same simplification noted in the
  source Pine script.
- Fixed Money position sizing is an approximation valid when your account
  currency matches the traded symbol's quote currency; use Risk % of
  Equity for accurate sizing on any symbol/account currency combination.
- The indicator's info panel and break-even/SL/TP simulation are for
  visualization only -- they do not reflect real fills, commission, or
  slippage. The EA's real trades are the source of truth once both are
  running together.
