# TradingView Pine Script v6 Prompt — 4H Candle Sweep + 5M Reversal Entry (Order Block / FVG)

Use this prompt with an AI code generator (or as your own build spec in the
Pine Editor) to produce a TradingView **Pine Script v6** indicator/strategy
for the setup described below.

---

## Prompt

```
Write a TradingView Pine Script v6 indicator/strategy called
"4H Candle Sweep Reversal + 5M OB/FVG Entry" with the following logic:

CONTEXT / TIMEFRAMES
- Primary detection timeframe: 4 Hour (4H)
- Entry confirmation timeframe: 5 Minute (5M)
- The script must run on any chart but pull 4H candle data via
  request.security() so it also works when the chart itself is on a
  lower timeframe (e.g. 5M), and separately pull 5M data for the entry
  confirmation logic.

STEP 1 — LIQUIDITY SWEEP PAIR (on the 4H timeframe)
- Candle 1 (C1) = the reference/previous 4H candle.
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
- Once a valid Sweep Signature is confirmed, arm the setup starting at
  the OPEN of the third 4H candle (C3) — i.e. the candle that opens
  immediately after C2 closes.
- From the open of C3 onward, the script should actively watch the 5M
  timeframe for an entry confirmation (see Step 3). Keep the setup
  "armed" until either a valid entry triggers or a user-defined
  invalidation occurs (e.g. price closes back beyond C2's sweep
  extreme on the 4H, or a max number of 5M bars/hours have elapsed
  without a trigger — expose this as an input).

STEP 3 — 5M ENTRY CONFIRMATION (Order Block or Fair Value Gap)
- Direction of the trade = the reversal direction implied by the sweep
  (if C2 swept and closed below C1's low, look for a BULLISH reversal
  entry; if C2 swept and closed above C1's high, look for a BEARISH
  reversal entry).
- On the 5M timeframe, once C3 (4H) is open, detect either:
    a) Order Block (OB): the last opposite-colored candle immediately
       preceding a strong displacement move in the reversal direction
       (e.g. for a bullish reversal, the last down-close 5M candle
       before an impulsive up move). Mark its high/low as the OB zone.
    b) Fair Value Gap (FVG): a 3-candle imbalance on the 5M chart where
       candle 1's high/low does not overlap with candle 3's low/high
       in the direction of the reversal (classic ICT 3-candle FVG).
       Mark the gap's top/bottom as the FVG zone.
- Entry trigger: price returns to (mitigates) the OB or FVG zone on the
  5M timeframe after the initial displacement, and shows a rejection
  (e.g. a wick into the zone with a close back in the direction of the
  reversal, or a bullish/bearish engulfing candle inside the zone).
- Only take the FIRST valid OB or FVG mitigation after C3 opens; ignore
  further signals until the current setup is invalidated or a trade is
  taken (expose "one signal per sweep" as a toggle input).

VISUALS
- Plot a box or bracket around C1+C2 on the 4H timeframe marking the
  sweep pair, labeled "Sweep" with an arrow showing swept direction.
- Plot a label at the open of C3 reading "Armed — watching 5M".
- On the 5M timeframe, draw a box around the detected OB or FVG zone,
  labeled "OB" or "FVG" accordingly.
- Plot a triangle/label at the confirmed entry bar reading "Long Entry"
  or "Short Entry" with the entry price.

ALERTS
- alertcondition() for: "Sweep Signature Detected", "Setup Armed (C3
  Open)", "OB/FVG Formed", and "Entry Triggered" (long and short
  variants).

INPUTS (user-configurable)
- Higher timeframe (default "240" / 4H)
- Lower/entry timeframe (default "5" / 5M)
- Require full-body close through swept level (bool, default true)
- Use Order Block detection (bool, default true)
- Use Fair Value Gap detection (bool, default true)
- Max bars/hours to wait for entry after arming (int)
- Colors for bullish/bearish zones and labels

CODE REQUIREMENTS
- Must declare //@version=6 and use current Pine Script v6 syntax
  (e.g. updated request.security() usage, box.new/label.new for
  drawings, input.* namespace functions).
- Use request.security() with gaps=barmerge.gaps_off and
  lookahead=barmerge.lookahead_off to avoid repainting on the 4H data.
- Keep state using var/varip variables to track the current
  Sweep Signature, armed status, and OB/FVG zone across bars.
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
