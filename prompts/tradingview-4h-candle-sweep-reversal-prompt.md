# TradingView Pine Script v6 Prompt — Candle Sweep Reversal + OB/FVG Entry (Multi Timeframe-Pair)

Use this prompt with an AI code generator (or as your own build spec in the
Pine Editor) to produce a TradingView **Pine Script v6** indicator/strategy
for the setup described below.

The same sweep/reversal logic applies to two selectable timeframe pairs:

| Pair | Sweep detection TF | Entry confirmation TF | Enable via settings |
|------|--------------------|------------------------|----------------------|
| A    | 4 Hour (4H)        | 5 Minute (5M)          | checkbox, default ON |
| B    | 1 Hour (1H)        | 1 Minute (1M)          | checkbox, default OFF |

Both pairs run the identical rules independently — only the timeframes
differ. Either, both, or neither can be active at a time, controlled by
tick-box inputs in the script settings.

---

## Prompt

```
Write a TradingView Pine Script v6 indicator/strategy called
"Candle Sweep Reversal + OB/FVG Entry (Multi-TF)" with the following logic:

CONTEXT / TIMEFRAMES
- The script supports two independent, user-toggleable timeframe pairs,
  each running the exact same sweep + reversal logic:
    Pair A: sweep detection on 4 Hour (4H), entry confirmation on 5 Minute (5M)
    Pair B: sweep detection on 1 Hour (1H), entry confirmation on 1 Minute (1M)
- Add a boolean input checkbox for each pair:
    "Enable 4H Sweep / 5M Entry" (default true)
    "Enable 1H Sweep / 1M Entry" (default false)
  Only run the detection/entry logic for a pair while its checkbox is on.
  Both pairs may be enabled simultaneously and must track state (armed
  setups, zones, alerts) independently of one another, clearly labeled
  by pair (e.g. "4H/5M" vs "1H/1M") in all boxes, labels, and alerts.
- Also expose the sweep and entry timeframes as free-text timeframe
  inputs (defaulting to "240"/"5" for Pair A and "60"/"1" for Pair B) so
  the user can retune either pair without editing code.
- The script must run on any chart but pull each pair's higher-timeframe
  candle data via request.security() so it also works when the chart
  itself is on a lower timeframe, and separately pull each pair's entry
  timeframe data for the entry confirmation logic.

STEP 1 — LIQUIDITY SWEEP PAIR (run once per enabled timeframe pair, on
that pair's sweep-detection timeframe, e.g. 4H for Pair A or 1H for Pair B)
- Candle 1 (C1) = the reference/previous candle on that timeframe.
- Candle 2 (C2) = the candle immediately following C1.
- Sweep condition (bearish version): C2's low trades below C1's low
  AND C2 CLOSES below C1's low (a full-body close through the level,
  not just a wick).
- Sweep condition (bullish version): C2's high trades above C1's high
  AND C2 CLOSES above C1's high.
- Opposite-color rule: C1 and C2 must NOT be the same candle color.
  One must be bullish (close > open) and the other bearish
  (close < open), in either order. If both candles are the same color,
  the pattern is invalid and must be rejected.
- When both the sweep condition and the opposite-color rule are true,
  mark this as a valid "Sweep Signature" and store:
    - sweep direction (bullish reversal expected / bearish reversal expected)
    - the high/low of C1 and C2 (used later as the reversal zone)
    - the bar index/time of C2 (the sweep candle)

STEP 2 — THIRD CANDLE TRIGGER
- Once a valid Sweep Signature is confirmed for a given pair, arm that
  pair's setup starting at the OPEN of the third candle (C3) on that
  pair's sweep-detection timeframe — i.e. the candle that opens
  immediately after C2 closes.
- From the open of C3 onward, the script should actively watch that
  pair's entry timeframe (5M for Pair A, 1M for Pair B) for an entry
  confirmation (see Step 3). Keep the setup "armed" until either a
  valid entry triggers or a user-defined invalidation occurs (e.g.
  price closes back beyond C2's sweep extreme on the sweep-detection
  timeframe, or a max number of entry-timeframe bars/hours have
  elapsed without a trigger — expose this as a per-pair input).

STEP 3 — ENTRY CONFIRMATION (Order Block or Fair Value Gap, on each
pair's entry timeframe: 5M for Pair A, 1M for Pair B)
- Direction of the trade = the reversal direction implied by the sweep
  (if C2 swept and closed below C1's low, look for a BULLISH reversal
  entry; if C2 swept and closed above C1's high, look for a BEARISH
  reversal entry).
- On the pair's entry timeframe, once that pair's C3 is open, detect
  either:
    a) Order Block (OB): the last opposite-colored candle immediately
       preceding a strong displacement move in the reversal direction
       (e.g. for a bullish reversal, the last down-close entry-timeframe
       candle before an impulsive up move). Mark its high/low as the
       OB zone.
    b) Fair Value Gap (FVG): a 3-candle imbalance on the entry
       timeframe where candle 1's high/low does not overlap with
       candle 3's low/high in the direction of the reversal (classic
       ICT 3-candle FVG). Mark the gap's top/bottom as the FVG zone.
- Entry trigger: price returns to (mitigates) the OB or FVG zone on the
  entry timeframe after the initial displacement, and shows a
  rejection (e.g. a wick into the zone with a close back in the
  direction of the reversal, or a bullish/bearish engulfing candle
  inside the zone).
- Only take the FIRST valid OB or FVG mitigation after that pair's C3
  opens; ignore further signals until the current setup is invalidated
  or a trade is taken (expose "one signal per sweep" as a toggle
  input, applied per pair).

VISUALS
- Plot a box or bracket around C1+C2 on the sweep-detection timeframe
  marking the sweep pair, labeled "Sweep [4H/5M]" or "Sweep [1H/1M]"
  (per pair) with an arrow showing swept direction.
- Plot a label at the open of C3 reading "Armed — watching 5M" or
  "Armed — watching 1M" depending on the pair.
- On the entry timeframe, draw a box around the detected OB or FVG
  zone, labeled "OB [pair]" or "FVG [pair]" accordingly.
- Plot a triangle/label at the confirmed entry bar reading "Long Entry
  [4H/5M]" / "Short Entry [1H/1M]" etc., with the entry price, so
  signals from each pair are visually distinguishable (e.g. different
  colors per pair).

ALERTS
- alertcondition() for each enabled pair: "Sweep Signature Detected",
  "Setup Armed (C3 Open)", "OB/FVG Formed", and "Entry Triggered"
  (long and short variants), with the pair name in the alert message
  so the user can tell which timeframe pair fired.

INPUTS (user-configurable)
- "Enable 4H Sweep / 5M Entry" (bool checkbox, default true)
  - 4H sweep-detection timeframe (default "240")
  - 5M entry timeframe (default "5")
- "Enable 1H Sweep / 1M Entry" (bool checkbox, default false)
  - 1H sweep-detection timeframe (default "60")
  - 1M entry timeframe (default "1")
- Require full-body close through swept level (bool, default true,
  applies to both pairs)
- Use Order Block detection (bool, default true)
- Use Fair Value Gap detection (bool, default true)
- Max bars/hours to wait for entry after arming (int, per pair)
- Colors for bullish/bearish zones and labels (optionally separate
  color sets per pair so 4H/5M and 1H/1M signals are visually distinct)

CODE REQUIREMENTS
- Must declare //@version=6 and use current Pine Script v6 syntax
  (e.g. updated request.security() usage, box.new/label.new for
  drawings, input.* namespace functions).
- Use request.security() with gaps=barmerge.gaps_off and
  lookahead=barmerge.lookahead_off to avoid repainting on any of the
  higher-timeframe data (4H or 1H).
- Keep state using var/varip variables to track each enabled pair's
  current Sweep Signature, armed status, and OB/FVG zone across bars,
  independently (e.g. separate state variables/arrays for Pair A and
  Pair B so enabling both does not cross-contaminate signals).
- Add clear inline comments only where the logic is non-obvious
  (e.g. why lookahead is disabled, why full-body close is required).
- Optimize for both overlay indicator use and strategy.entry/exit calls
  if built as a strategy (expose a toggle: "Indicator mode" vs
  "Strategy mode" using strategy.* calls with basic risk management —
  stop loss at the swept extreme, take profit at a user-defined R
  multiple).
```

---

## Notes on assumptions made when clarifying your description

- **"Previous candle sweep, next candle closes below the previous
  candle"** was interpreted as: the candle after the reference candle
  wicks through *and closes beyond* the reference candle's high/low —
  i.e. a full-body break, not just a wicking rejection.
- **"Previous and new candle must not be same... bullish and bearish or
  bearish and bullish"** was interpreted as: the two candles in the
  sweep pair must be opposite colors (this filters out simple
  same-direction continuation and keeps only genuine reversal-flavored
  sweeps).
- **"Third opening candle"** was interpreted as the open of the candle
  immediately following the 2-candle sweep pattern (candle #3 in the
  sequence), which is when the setup becomes "armed" for a lower
  timeframe entry.
- **"Reversal of the sweep"** was interpreted as trading back in the
  *opposite* direction of the sweep (fading the stop-hunt), which is
  the standard interpretation in liquidity-sweep / ICT-style setups.

If any of these assumptions don't match your intent (for example, if
you actually want the entry to continue *with* the sweep direction
rather than reverse it, or if "closes below the previous candle" means
something more specific like closing below the previous candle's
**close** rather than its **low**), let me know and I'll adjust the
prompt.
