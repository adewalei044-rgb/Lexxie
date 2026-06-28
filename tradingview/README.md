# 1H Retracement + FVG + Breakout Retest Strategy (Pine Script v6)

`1H_Retracement_FVG_Breakout_Strategy.pine` is a simpler, separate strategy (does not touch or replace the ICT MTF Confluence script below):

1. **1H trend** — the most recently closed 1H candle's body is fully above (bull) or below (bear) the prior 1H candle's body.
2. **Retracement zone** — a shallow pullback zone sized at `retracePct` (default 0.20 = 20%) of that 1H candle's range, measured from the breakout edge (top 20% of the range for a bull candle, bottom 20% for a bear candle).
3. **1m FVG in zone** — a 3-candle Fair Value Gap on the 1-minute chart must overlap that retracement zone (padded by `fvgZoneBufferPct` to allow near-misses).
4. **1m breakout + retest** — price must break a recent 1m swing high/low (`breakoutLookback` bars) in the trend direction, then retest (dip back to within `retestToleranceTicks` of) that broken level and hold, before entry.
5. **Risk management** — SL is placed just beyond the retested breakout level, TP is `rrMultiple` (default 2R). Same webhook JSON format as the ICT MTF Confluence strategy.

Like the other script, it has a "Step 0 - Enable / Disable Rules" group so each stage can be toggled off individually for testing, and a status table with diagnostic counters (Total Bars, Trend Bars, Zone Touch Bars, FVG Found Bars, Breakout Events, Retest Hits) to find the bottleneck if you get 0 trades.

---

# ICT MTF Confluence Strategy (Pine Script v6)

`ICT_MTF_Confluence_Strategy.pine` implements the multi-timeframe entry model:

## Turning rules on/off (Step 0)

The first input group, **"Step 0 - Enable / Disable Rules (for testing)"**, has one on/off switch per stage below: `4H Trend Filter`, `1H Momentum Body Shift`, `1H Gann Box Zone`, `1m Stop Hunt / Liquidity Sweep`, `1m/5m FVG Confluence`, `Rejection Candle Wick`. All default to **On**, which reproduces the exact original strategy behavior — flipping one Off bypasses just that stage (treats it as always-passing) so you can test, from the Inputs panel alone, which combination of stages is needed to get a trade without editing the script. Useful for isolating the zero-trades bottleneck reported by the diagnostic counters below.

1. **4H trend filter** — trend is bullish/bearish based on price vs. a 200-period MA (EMA or SMA, input-selectable) on the 4H chart.
2. **1H momentum + Gann box zone** — the most recently closed 1H candle's body must sit above (bull trend) or below (bear trend) the prior 1H candle's body, with `momentumOverlapPct` (default 0.25) allowing that fraction of the prior body's size to overlap before disqualifying the shift — set it to 0 for the original strict "zero overlap" rule. The 1H candle's low-to-high range is then divided with a Gann-box-style retracement: long entries are only considered while price is trading back into the **0.5–0.75** zone of that range, shorts into the **0.25–0.5** zone (both ratios are inputs).
3. **1m stop hunt** — a wick sweep of a recent swing low/high that closes back inside (liquidity grab) on the 1-minute chart, valid for a configurable number of bars.
4. **1m FVG with 5m confluence** — a 3-candle Fair Value Gap on the 1-minute chart is only actionable if its price range overlaps both the 1H Gann zone *and* an active, unfilled 5-minute FVG in the same direction. `fvgOverlapBufferPct` (default 1.0) pads both of those overlap checks by that multiple of each zone's own size, since exact-cent overlap across three narrow bands is rare in practice — set it to 0 for the original strict, exact-overlap-only rule.
5. **Rejection candle trigger** — the trade fires when a 1-minute candle wicks into that confluent FVG zone and closes back out with a wick at least `rejWickFactor × body` (default 1.5×) in the trade direction.

## Assumptions made (no response received when these were asked)

- **Stop-loss / take-profit**: SL is placed just beyond the stop-hunt wick that swept liquidity (plus a small tick buffer), TP is a configurable risk:reward multiple of that distance (default 2R). Both are inputs under "6) Risk Management" — change `rrMultiple` and `slBufferTicks`, or rewire the `strategy.exit()` calls if you'd rather use the FVG boundary or a fixed percentage instead.
- **FVG confluence rule**: defined as price-range overlap (with `fvgOverlapBufferPct` tolerance padding, default 1.0x) between the 1m FVG, the 1H Gann zone, and an active 5m FVG. Set `fvgOverlapBufferPct` to 0 for the original strict, exact-overlap-only rule, or adjust the overlap check in `findSetup()` directly for stricter containment instead.

## If you're seeing 0 trades / all-zero stats

The status table's Win/Loss/Win%/Drawdown rows only change once a trade closes, and the BUY/SELL labels only draw when `longSignal`/`shortSignal` fires. If those are all blank or zero, it almost always means the strategy hasn't found a single bar where **every** stage of the confluence chain (4H trend, 1H momentum shift, Gann zone, 1m stop hunt, FVG confluence, rejection wick) was true at once — not a bug, just a very strict setup.

The table now includes diagnostic counters (Total Bars, Trend Bars, Momentum Events, Zone Touch Bars, Stop Hunt Events, FVG Confluences, and FVG: Dir Match / Gann Hit / HTF Hit / Touch Hit) so you can see which stage is the bottleneck:

- **Trend Bars** close to **Total Bars** but **Momentum Events** near 0 → your instrument rarely produces clean non-overlapping 1H candle bodies; consider a more volatile pair or longer backtest range.
- **Zone Touch Bars** near 0 → price rarely retraces into the 0.5–0.75 / 0.25–0.5 box; check `longZoneLowPct`/`longZoneHighPct` inputs.
- **Stop Hunt Events** near 0 → widen `huntLookback`/`huntValidBars`.
- **FVG Confluences** near 0 even though the other counters are healthy → requiring a 1m FVG, the 1H Gann zone, and a 5m FVG to literally overlap in price is very strict, since all three are narrow bands. Raise `fvgOverlapBufferPct` (default 1.0) to pad the overlap checks so near-misses still count — the four **FVG: Dir Match / Gann Hit / HTF Hit / Touch Hit** rows show exactly which of the four sub-stages (FVG exists in the right direction → overlaps the Gann zone → overlaps a confluent 5m FVG → price has wicked back into it) is dropping to zero first.
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
