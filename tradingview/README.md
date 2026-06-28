# ICT MTF Confluence Strategy (Pine Script v6)

`ICT_MTF_Confluence_Strategy.pine` implements the multi-timeframe entry model:

1. **4H trend filter** — trend is bullish/bearish based on price vs. a 200-period MA (EMA or SMA, input-selectable) on the 4H chart.
2. **1H momentum + Gann box zone** — the most recently closed 1H candle's body must sit entirely above (bull trend) or below (bear trend) the prior 1H candle's body. The 1H candle's low-to-high range is then divided with a Gann-box-style retracement: long entries are only considered while price is trading back into the **0.5–0.75** zone of that range, shorts into the **0.25–0.5** zone (both ratios are inputs).
3. **1m stop hunt** — a wick sweep of a recent swing low/high that closes back inside (liquidity grab) on the 1-minute chart, valid for a configurable number of bars.
4. **1m FVG with 5m confluence** — a 3-candle Fair Value Gap on the 1-minute chart is only actionable if its price range overlaps both the 1H Gann zone *and* an active, unfilled 5-minute FVG in the same direction.
5. **Rejection candle trigger** — the trade fires when a 1-minute candle wicks into that confluent FVG zone and closes back out with a wick at least `rejWickFactor × body` (default 1.5×) in the trade direction.

## Assumptions made (no response received when these were asked)

- **Stop-loss / take-profit**: SL is placed just beyond the stop-hunt wick that swept liquidity (plus a small tick buffer), TP is a configurable risk:reward multiple of that distance (default 2R). Both are inputs under "6) Risk Management" — change `rrMultiple` and `slBufferTicks`, or rewire the `strategy.exit()` calls if you'd rather use the FVG boundary or a fixed percentage instead.
- **FVG confluence rule**: defined as price-range overlap between the 1m FVG and an active 5m FVG (not strict containment, not a distance tolerance). Adjust the overlap check in `findSetup()` if you want stricter containment instead.

## If you're seeing 0 trades / all-zero stats

The status table's Win/Loss/Win%/Drawdown rows only change once a trade closes, and the BUY/SELL labels only draw when `longSignal`/`shortSignal` fires. If those are all blank or zero, it almost always means the strategy hasn't found a single bar where **every** stage of the confluence chain (4H trend, 1H momentum shift, Gann zone, 1m stop hunt, FVG confluence, rejection wick) was true at once — not a bug, just a very strict setup.

The table now includes diagnostic counters (Total Bars, Trend Bars, Momentum Events, Zone Touch Bars, Stop Hunt Events, FVG Confluences) so you can see which stage is the bottleneck:

- **Trend Bars** close to **Total Bars** but **Momentum Events** near 0 → your instrument rarely produces clean non-overlapping 1H candle bodies; consider a more volatile pair or longer backtest range.
- **Zone Touch Bars** near 0 → price rarely retraces into the 0.5–0.75 / 0.25–0.5 box; check `longZoneLowPct`/`longZoneHighPct` inputs.
- **Stop Hunt Events** near 0 → widen `huntLookback`/`huntValidBars`.
- **FVG Confluences** near 0 even though the other counters are healthy → 1m/5m FVGs rarely overlap each other and the Gann zone at the same time on this symbol; try a higher-volatility instrument or loosen `fvgMaxAge`/`rejWickFactor`.
- All counters healthy but still 0 trades → the bottleneck is the *intersection* of all conditions on the same bar; this is expected for a 6-factor confluence model and may take a longer backtest window (more 1m bars) to produce its first trade.

## Setup on TradingView

1. Add the script to a **1-minute chart** (the script pulls 4H/1H/5m data internally via `request.security`, so the chart timeframe only needs to match the entry/FVG timeframe inputs).
2. Tune the input groups (trend MA, Gann zone ratios, stop-hunt lookback, FVG age/confluence window, rejection wick ratio, risk:reward) to taste — none are hardcoded.
3. Backtest via the Strategy Tester tab before risking anything live.

## Wiring up the webhook

Pine Script cannot call a URL on its own — TradingView's alert system sends the webhook request, not the script. To connect this to a bot/automation:

1. With the strategy on the chart, click **Alert** → **Condition**: select this strategy.
2. Choose **"Order fills"** (or "Any alert() function call") so `alert_message` payloads from `strategy.entry`/`strategy.exit` are used.
3. Check **"Webhook URL"** and paste your receiver's endpoint.
4. The body TradingView POSTs is exactly the JSON built in the script, e.g.:
   ```json
   {"action":"buy","symbol":"BTCUSDT","side":"long","price":67123.5,"sl":66980.0,"tp":67410.5,"qty":1,"strategy":"ICT-MTF-Confluence","time":"2026-06-28T10:15:00Z"}
   ```
5. Edit the `webhookSymbol` and `qtyForAlert` inputs, or the `str.format(...)` templates in the script, to match whatever schema your receiving bot/server expects (e.g. 3Commas, an n8n workflow, your own webhook server).

A live TradingView plan is required for webhook alerts (not available on the free tier).
