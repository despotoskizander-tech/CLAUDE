# Retention guide (Roblox)

Notes from Roblox's retention analytics docs, kept here so they can guide
design and code decisions for our games.

## Where to find it

Creator Dashboard → Creations → pick the game → Analytics → **Retention**.
Group-owned games need the group's analytics permission.

## How to read the charts

- The x-axis is a new user's **first play date**. One date is one cohort
  across the D1, D7 and D30 charts.
  - D1: first played on that date and came back the next day.
  - D7: came back on day 7 (the 8th day).
  - D30: came back on day 30 (the 31st day).
- Recent dates on D7/D30 are empty until 7 or 30 days have passed
  (a 06/20 cohort shows D7 on 06/27 and D30 on 07/20).
- A dip on all three charts on one date usually means a big influx of new
  users that day. It is normal and temporary.

## Cohort table (bottom of the dashboard)

- **Daily** cohorts: retention over each cohort's first 10 days.
- **Weekly** cohorts: retention over 10 weeks, grouped Monday–Sunday.
- Use cohorts to judge updates, events and marketing: compare users who
  joined during an event with users who joined before it.
- Per-cohort metrics (all cumulative): 7D playtime per user, 7D payer
  conversion rate, 7D revenue per user, 30D revenue per user.

## What drives each metric

| Metric | Focus on | Main levers |
|---|---|---|
| D1 | Core loop, first-time user experience (FTUE), performance | Clear, fun, rewarded loop; short onboarding; stable game |
| D7 | Progression system | Clear goals, content variety, balanced pace |
| D30 | Ending system (late game) | Regular updates, social features |

### D1: core loop

The core loop is what players repeat each session to progress
(pets: adopt → train → level up; tycoon: run business → balance resources →
compete).

1. Make each step clear and fun.
2. Balance the challenge: not frustrating, not boring.
3. Reward completion with feedback, currency, items and achievements.

### D1: first-time user experience

- Short tutorial or tooltips; no long tutorials. Reach the fun in
  **5 minutes or less**.
- Give a joyful moment after the first loop completes.
- Preview the progress players get by repeating the loop.
- Measure it as a funnel:
  1. List the loop's steps.
  2. Track completion of each step, plus good and bad outcomes
     (for example, won or lost the first NPC battle).
  3. Find the biggest drop-off and remove friction there (for example,
     make the pet store easier to find).

### D1: performance

- Test on many devices and platforms.
- Watch crash rate, frame rate and errors after every update.
- Build a player community that reports bugs.

### D7: progression

- Short-term goals for instant reward, long-term goals for direction.
- Variety: new modes, items, social features.
- Pace: too fast runs out of content, too slow frustrates.
- Measure it: define the progression (currency earned, items unlocked,
  skills mastered), log when each player reaches each level, look at how
  many players sit at each level and how long each level takes, then retune
  tasks that are too quick or too slow.

### D30: ending system

- Content cadence: small updates to existing mechanics every **2–4 weeks**,
  big new features every **2–3 months**.
- Social systems keep players around between updates: trading, parties,
  guilds, PvP, tournaments, leaderboards.

## Applying it in this codebase

- Track funnel and progression steps from the server. Roblox's
  `AnalyticsService` has `LogOnboardingFunnelStepEvent` (FTUE steps) and
  `LogProgressionEvent` (levels), which feed the Analytics dashboards.
- Progress that must persist (levels, unlocks, "finished tutorial" flags)
  goes in `TEMPLATE` in `src/server/PlayerDataService.lua`.
- Leaderboards for the D30 social layer use an ordered data store
  (see the DataStore rules in `CLAUDE.md`).
