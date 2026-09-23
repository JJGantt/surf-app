# Open work

## The short-term model

Surfline's model covers days and is hours stale by the time it matters — the forecast in hand at 5am
is the previous evening's run, a median of 14.5 hours old in summer. The model here covers HOURS, and
it corrects that forecast rather than replacing it.

**The shape: measure the divergence, carry it forward, let it decay.**

1. **Measure the divergence continuously**, not in hourly buckets. The dock reports wind every six
   minutes and the buoys every thirty, so the comparison is each reading against what the capture in
   hand predicted for that moment. Divergence is per VARIABLE — wind speed, wind direction, swell
   height, swell period — because they behave nothing alike.
2. **It has to be SUSTAINED to count.** One reading apart from the model is noise; a divergence that
   holds across consecutive readings is a model that has the day wrong. It is re-measured on every
   reading, so a divergence that closes shrinks on its own — there is no state to reset.
3. **Apply it forward with a decaying weight.** Full correction at the next hour, tapering to nothing
   a few hours out, where the model is trusted again. The stronger and longer-held the divergence, the
   further it carries.

**THE DECAY RATE IS MEASURABLE AND MUST NOT BE GUESSED.** Given a divergence of X at hour T, how much
of X survives at T+1, T+2, T+3? That is the autocorrelation of forecast error, and the archive already
answers it: `surf_snapshots` holds every capture with its timestamp, so "what was predicted for 9am as
of the 5am run" is a lookup, and `water_readings` / `wave_readings` hold what actually happened. Fit
the curve per variable and the taper stops being a tuning knob.

**Expect wind and swell to decay at very different rates**, which is why they cannot share a curve.
Wind error is local and turns over fast — the land breeze gives way to a sea breeze around midday
(median 13:00, `status-hub/docs/ALARMS.md`). Swell is inertial: a swell running bigger than forecast
stays bigger for many hours. 2026-09-22 shows both — the wind ran 50 degrees off the model for six
straight hours while the swell was byte-identical in every capture of that morning.

**There is no labelling to do, and no rating to collect.** Surfline RE-RATES ITS OWN PAST once
observations are in, and every capture is archived, so the final rating for an hour is the label —
free, and produced by the same source being corrected. That is exactly what the wind-upgrade backtest
scored against.

One dependency, and it is a real one: that label is SAME-DAY and unstable. The last capture covering
an hour lands a median 7.5 hours after it, and 26% of hours whose last capture says Fair did not say
Fair in the one before. Fixing the capture cadence — and keeping one capture at least 24 hours after
each hour — is what turns this into something scoreable. It is logged in `status-hub/docs/TODO.md`
and it is the prerequisite, not a nicety.

**Presentation: a toggle between Surfline's own numbers and the corrected ones.** Showing both is what
makes the correction auditable — it can be judged against the raw forecast over time instead of
silently rewriting it.
