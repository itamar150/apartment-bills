# Apartment Bills — Project Instructions

## Overview

Single-file Hebrew RTL PWA (`index.html`) for managing bi-monthly apartment bills between two parties:
- **הבית שלי** ("My House") — the main residence
- **היחידה** ("The Unit") — a rental unit sharing some expenses

The app is a PWA with a manifest (`manifest.json`) and icons. UI language is Hebrew, direction RTL.

---

## Billing Cycle

Cycles are **bi-monthly**, always starting on even months (Jan=0, Mar=2, May=4, …).

- The active cycle is derived from the most recent row in `cycles` table: `next_cycle = last.cycle_month + 2` (wrapping year if needed).
- When no cycles exist, the cycle is inferred from the current date (even-month start).
- A cycle **finalizes** when all four bill types are marked paid → `finalizeCycle()` writes to `cycles` and advances `csm/csy` by 2.

---

## Bill Types & Calculation Logic

### 1. Electricity — חשמל (bi-monthly)
Inputs: `mc` (current meter reading in kWh), `eb` (total invoice ₪)

```
diff      = current_reading - previous_reading
unit_amt  = 30 + diff * 0.6402
mine_amt  = max(0, bill - unit_amt)
```

The unit pays a fixed ₪30 base plus ₪0.6402/kWh. My house pays the remainder.

### 2. Vaad Tzofim — ועד מקומי צופים (monthly × 2)
Two separate monthly bills per cycle (`v1` = month 1, `v2` = month 2, where month 2 = `(csm+1) % 12`).

Inputs per bill: `shimira` (שמירה, security), `misim` (מיסים, taxes), `mayim_a` (מים א׳, water A), `mayim_b` (מים ב׳, water B)

```
unit_amt = (misim / 3) + (mayim_a / 2) + (mayim_b / 2)
mine_amt = shimira + (misim * 2/3) + (mayim_a / 2) + (mayim_b / 2)
total    = shimira + misim + mayim_a + mayim_b
```

Shimira is paid entirely by My House. Misim is split 1/3 unit, 2/3 mine. Water is split 50/50.

### 3. Arnona & Biyuv — ארנונה וביוב (bi-monthly)
Inputs: `aa` (arnona/municipal tax ₪), `ab` (biyuv/sewage+water ₪)

```
unit_amt = (arnona / 3) + (biyuv / 2)
mine_amt = (arnona * 2/3) + (biyuv / 2)
```

Arnona split 1/3 unit, 2/3 mine. Biyuv split 50/50.

---

## Supabase Integration

- **Project URL**: `https://pgerlxygrvkoppfpxnqn.supabase.co`
- **Anon key**: stored in `SUPABASE_KEY` constant in `index.html`
- Client initialized via CDN: `@supabase/supabase-js@2`

### Tables

| Table | Key columns | Conflict key |
|---|---|---|
| `cycles` | cycle_month, cycle_year, unit_paid, unit_paid_date | cycle_month, cycle_year |
| `electricity_readings` | cycle_month, cycle_year, previous_reading, current_reading, kwh_used, bill_amount, unit_amount, mine_amount, paid_to_supplier | cycle_month, cycle_year |
| `vaad_bills` | cycle_month, cycle_year, bill_month, bill_year, shimira, misim, mayim_a, mayim_b, total, unit_amount, mine_amount, paid_to_supplier | cycle_month, cycle_year, bill_month, bill_year |
| `arnona_bills` | cycle_month, cycle_year, arnona_amount, biyuv_amount, total, unit_amount, mine_amount, paid_to_supplier | cycle_month, cycle_year |

All writes use `upsert` with the conflict key to allow re-saves.

### Key DB Functions
- `loadCurrentCycle()` — reads most recent `cycles` row to set `csm/csy`
- `loadPrevReading()` — reads most recent `electricity_readings.current_reading` (ordered by `created_at DESC`) to set `prevReading` (fallback: 76007.5)
- `loadCurrentEntries()` — loads all four bill types for current `csm/csy` and restores UI state
- `saveBill(k)` — upserts the given bill type, then calls `lockCard(k)` on success
- `finalizeCycle()` — upserts `cycles` row, advances cycle, resets entry form

---

## UI Structure

- **Tab: הזנת חשבון** (entry) — input cards for each bill type, live-calculated split preview, summary accordion
- **Tab: היסטוריה** (history) — historical cycles with unit/mine totals and unit-payment tracking
- Cards lock (inputs disabled, pill becomes `.locked`) after saving to Supabase
- "שולם" (Paid) pill toggles: `open` → `closed` → triggers `saveBill()` → `lockCard()`
- Unit payment tracked separately: "שילמה היחידה" button marks `cycles.unit_paid = true`

---

## State Variables (runtime)

```js
csm, csy       // current cycle month (0-based) and year
prevReading    // previous electricity meter reading
cycleId        // current cycle UUID (from cycles table)
unitPaid       // whether the unit has paid this cycle
paid           // { elec, v1, v2, ar } — paid flags per bill type
euV, emV       // electricity: unit & mine amounts
v1uV, v1mV     // vaad month 1: unit & mine
v2uV, v2mV     // vaad month 2: unit & mine
aruV, armV     // arnona: unit & mine
```

---

## Notes

- All monetary values formatted as `₪ X.XX` via `f(n)` helper
- Month names use Hebrew `HM` array (0=ינואר … 11=דצמבר)
- Cycle period displayed as "Month1 – Month2 Year" (the second month's year)
- No build step, bundler, or framework — plain HTML/CSS/JS
