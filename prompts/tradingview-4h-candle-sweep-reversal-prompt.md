# TradingView Pine Script v6 Prompt — Multi-Strategy: Sweep Reversal & Trend Continuation (OB/FVG Entries)

Use this prompt with an AI code generator (or as your own build spec in the
Pine Editor) to produce a TradingView **Pine Script v6** indicator/strategy
for the setups described below.

The script houses **two independent strategies**, each with its own master
ON/OFF toggle in settings, and each strategy's individual timeframes also
get their own ON/OFF toggle buttons:

| Strategy | What it does | Master settings toggle | Default |
|----------|---------------|--------------------------|---------|
| 1. Sweep Reversal | Liquidity sweep of the previous candle by an opposite-colored candle, armed on the 3rd candle's open, entry via OB/FVG mitigation on a lower timeframe | "Enable Strategy 1: Sweep Reversal" | ON |
| 2. Trend Continuation | A trend-aligned candle that closes beyond the previous candle (continuation/breakout), armed on the next candle, entry via FVG reversal/pullback on a lower timeframe | "Enable Strategy 2: Trend Continuation" | OFF |

Within Strategy 1, every individual timeframe also gets its own ON/OFF
toggle (as established previously):

| Timeframe | Role | Settings toggle | Default |
|-----------|------|------------------|---------|
| 4 Hour (4H) | Sweep detection | "4H Sweep Detection: ON/OFF" | ON |
| 5 Minute (5M) | Entry confirmation | "5M Entry Confirmation: ON/OFF" | ON |
| 1 Hour (1H) | Sweep detection | "1H Sweep Detection: ON/OFF" | OFF |
| 1 Minute (1M) | Entry confirmation | "1M Entry Confirmation: ON/OFF" | OFF |

A timeframe pair is only active when both its sweep-detection toggle and
its entry-confirmation toggle are switched ON.

Strategy 2 runs on its own fixed pair by default (1H trend candle → 1M FVG
entry), also exposed as individually toggleable timeframes so it can be
retuned the same way.

---

## Prompt

```
Write a TradingView Pine Script v6 indicator/strategy called
"Multi-Strategy: Sweep Reversal & Trend Continuation (OB/FVG)" with the
following logic:

================================================================
GLOBAL STRUCTURE
================================================================
- The script contains two independently toggleable strategies. Add a
  master boolean input for each:
    input.bool(true,  "Enable Strategy 1: Sweep Reversal")
    input.bool(false, "Enable Strategy 2: Trend Continuation")
  Only run a strategy's detection/entry logic while its master toggle is
  ON. Both strategies may run simultaneously without interfering with
  each other's state, drawings, or alerts. Tag every box, label, and
  alert with the strategy name/number so signals are distinguishable
  (e.g. "S1" vs "S2").
- Each strategy exposes its own timeframe pair, and every individual
  timeframe within each strategy gets its own boolean ON/OFF toggle
  input (not one combined switch per pair) plus a free-text timeframe
  input so it can be retuned without editing code.
- Pull all higher-timeframe candle data via request.security() with
  gaps=barmerge.gaps_off and lookahead=barmerge.lookahead_off to avoid
  repainting, for both strategies.

================================================================
STRATEGY 1 — SWEEP REVERSAL (existing logic, unchanged)
================================================================
TIMEFRAMES
    input.bool(true,  "4H Sweep Detection")      // ON by default
    input.bool(true,  "5M Entry Confirmation")   // ON by default
    input.bool(false, "1H Sweep Detection")      // OFF by default
    input.bool(false, "1M Entry Confirmation")   // OFF by default
  A pair is active when both its sweep-detection toggle and its
  entry-confirmation toggle are ON (e.g. 4H+5M = Pair A, 1H+1M = Pair B).
  Free-text timeframe inputs default to "240"/"5"/"60"/"1" respectively.

STEP 1 — LIQUIDITY SWEEP PAIR (run once per enabled timeframe pair, on
that pair's sweep-detection timeframe)
- Candle 1 (C1) = the reference/previous candle on that timeframe.
- Candle 2 (C2) = the candle immediately following C1.
- Sweep condition (bearish version): C2's low trades below C1's low
  AND C2 CLOSES below C1's low (a full-body close through the level,
  not just a wick).
- Sweep condition (bullish version): C2's high trades above C1's high
  AND C2 CLOSES above C1's high.
- Opposite-color rule: C1 and C2 must NOT be the same candle color. One
  must be bullish (close > open) and the other bearish (close < open),
  in either order. If both candles are the same color, reject the
  pattern.
- When both the sweep condition and the opposite-color rule are true,
  mark this as a valid "Sweep Signature" and store the sweep direction,
  the high/low of C1 and C2, and the bar index/time of C2.

STEP 2 — THIRD CANDLE TRIGGER
- Once a valid Sweep Signature is confirmed, arm the setup starting at
  the OPEN of the third candle (C3) on that pair's sweep-detection
  timeframe — the candle that opens immediately after C2 closes.
- From the open of C3 onward, watch that pair's entry timeframe for an
  entry confirmation (Step 3). Keep the setup "armed" until either a
  valid entry triggers or an invalidation occurs (price closes back
  beyond C2's sweep extreme, or a max number of entry-timeframe
  bars/hours elapse without a trigger — expose as a per-pair input).

STEP 3 — ENTRY CONFIRMATION (Order Block or Fair Value Gap, on the
pair's entry timeframe)
- Direction of the trade = the reversal direction implied by the sweep
  (swept and closed below C1's low → look for a BULLISH entry; swept
  and closed above C1's high → look for a BEARISH entry).
- Once C3 is open, detect either:
    a) Order Block (OB): the last opposite-colored candle immediately
       preceding a strong displacement move in the reversal direction.
       Mark its high/low as the OB zone.
    b) Fair Value Gap (FVG): a 3-candle imbalance where candle 1's
       high/low does not overlap candle 3's low/high in the reversal
       direction (classic ICT 3-candle FVG). Mark the gap as the FVG
       zone.
- Entry trigger: price returns to (mitigates) the OB or FVG zone after
  the initial displacement and shows a rejection (wick into the zone
  with a close back in the reversal direction, or an engulfing candle
  inside the zone).
- Only take the FIRST valid mitigation after C3 opens per pair; ignore
  further signals until invalidated or a trade is taken (toggle input:
  "one signal per sweep").

================================================================
STRATEGY 2 — TREND CONTINUATION + FVG REVERSAL ENTRY (new)
================================================================
TIMEFRAMES
    input.bool(true, "1H Trend Candle Detection")   // ON by default
    input.bool(true, "1M FVG Entry Confirmation")   // ON by default
  Both individually toggleable and retunable via free-text timeframe
  inputs, defaulting to "60" (1H) and "1" (1M). This strategy is only
  active while its master toggle ("Enable Strategy 2") AND both of
  these timeframe toggles are ON.

STEP 1 — TREND DIRECTION (1H)
- Add a "Trend Detection Method" input with options:
    a) "Auto (EMA)": trend is bullish when close is above a
       user-configurable EMA (default length 50) on the 1H timeframe,
       bearish when below.
    b) "Auto (Structure)": trend is bullish when price is making
       higher highs and higher lows over the last N swing points
       (expose N as an input, default 3), bearish when making lower
       highs and lower lows.
    c) "Manual": user explicitly selects Bullish or Bearish bias via a
       dropdown input, overriding automatic detection.
  Default method: "Auto (EMA)".

STEP 2 — TREND CONTINUATION CANDLE (1H)
- Candle X = a 1H candle whose color matches the current trend
  direction (bullish candle, close > open, if trend is bullish;
  bearish candle, close < open, if trend is bearish).
- Continuation condition (bullish trend): Candle X CLOSES above the
  previous candle's high (full-body close beyond the prior candle,
  confirming displacement in the trend direction).
- Continuation condition (bearish trend): Candle X CLOSES below the
  previous candle's low.
- When both the trend-aligned color and the continuation-close
  condition are true, mark this as a valid "Continuation Signature" and
  store the trend direction, Candle X's high/low, and its bar
  index/time.
- Note: unlike Strategy 1, Candle X and the previous candle are NOT
  required to be opposite colors — this is a trend-following
  continuation pattern, not a reversal sweep.

STEP 3 — NEXT CANDLE TRIGGER
- Once a valid Continuation Signature is confirmed, arm the setup
  starting at the OPEN of the very next 1H candle (the candle
  immediately after Candle X closes).
- From that open onward, watch the 1M timeframe for a Fair Value Gap
  reversal/pullback entry (Step 4). Keep the setup "armed" until either
  a valid entry triggers or an invalidation occurs (price closes back
  through Candle X's open on the 1H, i.e. the continuation fails, or a
  max number of 1M bars/hours elapse without a trigger — expose as an
  input).

STEP 4 — 1M FVG REVERSAL/PULLBACK ENTRY
- Direction of the trade = the SAME direction as the trend/continuation
  (this is a trend-following pullback entry, not a fade): bullish trend
  → look for a BULLISH entry; bearish trend → look for a BEARISH entry.
- On the 1M timeframe, once armed, detect a Fair Value Gap (3-candle
  imbalance, same definition as Strategy 1) that formed during the
  continuation move.
- Entry trigger: price pulls back ("reversal" in the small-timeframe
  sense — a retracement, not a trend reversal) into the 1M FVG zone and
  shows a rejection back in the trend direction (wick into the zone
  with a close back in the trend direction, or a trend-aligned
  engulfing candle inside the zone).
- Only take the FIRST valid FVG mitigation after arming; ignore further
  signals until invalidated or a trade is taken (toggle input: "one
  signal per continuation").

================================================================
VISUALS
================================================================
- Strategy 1: box/bracket around C1+C2 on the sweep-detection
  timeframe labeled "Sweep [S1 4H/5M]" or "Sweep [S1 1H/1M]" with an
  arrow showing swept direction; "Armed" label at C3's open; OB/FVG box
  on the entry timeframe; entry triangle/label with price.
- Strategy 2: box/bracket around the previous candle + Candle X on the
  1H timeframe labeled "Continuation [S2 1H/1M]" with an arrow showing
  trend direction; "Armed" label at the next candle's open; FVG box on
  the 1M timeframe; entry triangle/label with price.
- Use visually distinct colors/label prefixes ("S1" vs "S2") so signals
  from the two strategies are never confused, especially when both are
  enabled at once.

================================================================
ALERTS
================================================================
- Strategy 1: alertcondition() for "Sweep Signature Detected", "Setup
  Armed (C3 Open)", "OB/FVG Formed", "Entry Triggered" (long/short),
  each labeled with the active pair.
- Strategy 2: alertcondition() for "Continuation Signature Detected",
  "Setup Armed (Next Candle Open)", "FVG Formed", "Entry Triggered"
  (long/short), each labeled "S2".

================================================================
INPUTS (user-configurable, grouped by strategy)
================================================================
Strategy 1:
- "Enable Strategy 1: Sweep Reversal" (bool, default true)
- "4H Sweep Detection: ON/OFF" (bool, default ON) + timeframe text
  input (default "240")
- "5M Entry Confirmation: ON/OFF" (bool, default ON) + timeframe text
  input (default "5")
- "1H Sweep Detection: ON/OFF" (bool, default OFF) + timeframe text
  input (default "60")
- "1M Entry Confirmation: ON/OFF" (bool, default OFF) + timeframe text
  input (default "1")
- Require full-body close through swept level (bool, default true)
- Use Order Block detection (bool, default true)
- Use Fair Value Gap detection (bool, default true)
- Max bars/hours to wait for entry after arming (int, per pair)

Strategy 2:
- "Enable Strategy 2: Trend Continuation" (bool, default false)
- "1H Trend Candle Detection: ON/OFF" (bool, default ON) + timeframe
  text input (default "60")
- "1M FVG Entry Confirmation: ON/OFF" (bool, default ON) + timeframe
  text input (default "1")
- "Trend Detection Method" (dropdown: Auto EMA / Auto Structure /
  Manual, default Auto EMA)
- EMA length for trend filter (int, default 50, used when method =
  Auto EMA)
- Swing lookback N for structure trend filter (int, default 3, used
  when method = Auto Structure)
- Manual trend bias (dropdown: Bullish / Bearish, used when method =
  Manual)
- Require full-body close beyond previous candle (bool, default true)
- Max bars/hours to wait for entry after arming (int)

Shared:
- Colors for bullish/bearish zones and labels, with separate color sets
  per strategy/pair so all active signals stay visually distinct.

================================================================
CODE REQUIREMENTS
================================================================
- Must declare //@version=6 and use current Pine Script v6 syntax
  (updated request.security() usage, box.new/label.new for drawings,
  input.* namespace functions).
- Use request.security() with gaps=barmerge.gaps_off and
  lookahead=barmerge.lookahead_off for all higher-timeframe pulls (4H,
  1H) to avoid repainting.
- Keep state using var/varip variables to track each strategy's/pair's
  current Signature, armed status, and OB/FVG/FVG zone across bars,
  fully independently (separate state for Strategy 1's pairs and
  Strategy 2, so enabling multiple simultaneously never cross-
  contaminates signals).
- Add clear inline comments only where the logic is non-obvious (e.g.
  why lookahead is disabled, why full-body close is required, why
  Strategy 2 trades WITH the trend while Strategy 1 trades AGAINST the
  sweep).
- Optimize for both overlay indicator use and strategy.entry/exit calls
  if built as a strategy (toggle: "Indicator mode" vs "Strategy mode"
  using strategy.* calls with basic risk management — Strategy 1: stop
  loss at the swept extreme; Strategy 2: stop loss at Candle X's open
  or the FVG zone edge; both with a user-defined take-profit R
  multiple).
```

---

## Notes on assumptions made when clarifying your description

**Strategy 1 (Sweep Reversal):**
- **"Previous candle sweep, next candle closes below the previous
  candle"** was interpreted as: the candle after the reference candle
  wicks through *and closes beyond* the reference candle's high/low —
  a full-body break, not just a wicking rejection.
- **"Previous and new candle must not be same... bullish and bearish or
  bearish and bullish"** was interpreted as: the two candles in the
  sweep pair must be opposite colors.
- **"Third opening candle"** was interpreted as the open of the candle
  immediately following the 2-candle sweep pattern.
- **"Reversal of the sweep"** was interpreted as trading back in the
  *opposite* direction of the sweep (fading the stop-hunt).

**Strategy 2 (Trend Continuation, new):**
- **"Bullish or bearish candle on a trend closes above the previous
  candle"** was interpreted as: a candle matching the prevailing trend
  direction that closes beyond (above the high, for a bullish trend;
  below the low, for a bearish trend) the prior candle — a
  displacement/continuation candle. Since you didn't specify how
  "trend" is determined, the prompt exposes it as a configurable input
  (EMA-based, swing-structure-based, or manual bias) so you can pick
  the definition that matches your usual analysis.
- **"Trade next candle reversal on 1 minute timeframe FVG"** was
  interpreted as: once the continuation candle closes and the next 1H
  candle opens, drop to 1M and wait for price to pull back
  ("reversal" here meaning a short-term retracement, not a full trend
  reversal) into a Fair Value Gap, then enter WITH the trend on
  rejection from that FVG. This is the opposite trade direction from
  Strategy 1 (which fades/reverses the sweep) — Strategy 2 trades in
  the same direction as the identified trend.

If either of these assumptions doesn't match your intent — particularly
how "trend" should be defined for Strategy 2, or whether the 1M FVG
entry should instead fade the continuation candle rather than ride the
trend — let me know and I'll adjust the prompt.
