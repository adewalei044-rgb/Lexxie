# TradingView Pine Script v6 Prompt — Candle Sweep Reversal + OB/FVG Entry (Multi Timeframe-Pair)

Use this prompt with an AI code generator (or as your own build spec in the
Pine Editor) to produce a TradingView **Pine Script v6** indicator/strategy
for the setup described below.

The same sweep/reversal logic applies to two selectable timeframe pairs,
and every individual timeframe involved gets its own **ON/OFF toggle
button** in the script settings (not just a single switch per pair):

| Timeframe | Role              | Settings toggle              | Default |
|-----------|--------------------|------------------------------|---------|
| 4 Hour (4H) | Sweep detection  | "4H Sweep Detection: ON/OFF" | ON      |
| 5 Minute (5M) | Entry confirmation | "5M Entry Confirmation: ON/OFF" | ON      |
| 1 Hour (1H) | Sweep detection  | "1H Sweep Detection: ON/OFF" | OFF     |
| 1 Minute (1M) | Entry confirmation | "1M Entry Confirmation: ON/OFF" | OFF     |

A timeframe **pair is only active when both its sweep-detection toggle
and its entry-confirmation toggle are switched ON** (e.g. 4H ON + 5M ON
= Pair A running). This also lets an advanced user mix and match (e.g.
4H sweep detection with 1M entry confirmation) simply by flipping the
individual toggles, rather than being locked into fixed pairs.

---

## Prompt

```
Write a TradingView Pine Script v6 indicator/strategy called
"Candle Sweep Reversal + OB/FVG Entry (Multi-TF)" with the following logic:

CONTEXT / TIMEFRAMES
- The script supports two timeframe pairs, each running the exact same
  sweep + reversal logic:
    Pair A: sweep detection on 4 Hour (4H), entry confirmation on 5 Minute (5M)
    Pair B: sweep detection on 1 Hour (1H), entry confirmation on 1 Minute (1M)
- Every individual timeframe gets its OWN boolean ON/OFF toggle input
  in settings (not one combined switch per pair):
    input.bool(true,  "4H Sweep Detection")      // ON by default
    input.bool(true,  "5M Entry Confirmation")   // ON by default
    input.bool(false, "1H Sweep Detection")      // OFF by default
    input.bool(false, "1M Entry Confirmation")   // OFF by default
  A pair is only actively traded when BOTH of its toggles are ON (e.g.
  4H Sweep Detection ON + 5M Entry Confirmation ON = Pair A running).
  This also allows mixed combinations if the user turns on, say, 4H
  Sweep Detection + 1M Entry Confirmation.
  Only run detection/entry logic for timeframe combinations where both
  relevant toggles are on, and track state (armed setups, zones,
  alerts) independently per active combination, clearly labeled by
  timeframe (e.g. "4H/5M" vs "1H/1M" vs any mixed combo) in all boxes,
  labels, and alerts.
- Also expose each of the four timeframes as free-text timeframe
  inputs (defaulting to "240" for 4H, "5" for 5M, "60" for 1H, "1" for
  1M) so the user can retune any of them without editing code, in
  addition to their individual ON/OFF toggle.
- The script must run on any chart but pull each active sweep-detection
  timeframe's candle data via request.security() so it also works when
  the chart itself is on a lower timeframe, and separately pull each
  active entry-confirmation timeframe's data for the entry confirmation
  logic.

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
- "4H Sweep Detection: ON/OFF" (bool toggle, default ON)
  - 4H sweep-detection timeframe text input (default "240")
- "5M Entry Confirmation: ON/OFF" (bool toggle, default ON)
  - 5M entry timeframe text input (default "5")
- "1H Sweep Detection: ON/OFF" (bool toggle, default OFF)
  - 1H sweep-detection timeframe text input (default "60")
- "1M Entry Confirmation: ON/OFF" (bool toggle, default OFF)
  - 1M entry timeframe text input (default "1")
- Require full-body close through swept level (bool, default true,
  applies to all active combinations)
- Use Order Block detection (bool, default true)
- Use Fair Value Gap detection (bool, default true)
- Max bars/hours to wait for entry after arming (int, per active
  combination)
- Colors for bullish/bearish zones and labels (optionally separate
  color sets per combination so 4H/5M, 1H/1M, or any mixed pairing are
  visually distinct)

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
