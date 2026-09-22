# Open work

## TestFlight

`internal_main` exists but is empty: adding the tester account through the API was refused
("Tester(s) cannot be assigned") before the app had a build. Retry once the first build has
processed; if it still refuses, it is one click in App Store Connect's TestFlight tab.

## The short-term model

Surfline's model covers days and is hours stale by morning (the 5am forecast is the 8pm run). The
model here covers hours:

1. Learn Surfline's rating as a function of its own inputs (size, swell, period, direction, wind,
   tide) from the hourly forecast archive in `surf_snapshots` / `surf_hours`.
2. Feed it MEASURED inputs — buoy swell and the dock's wind — for a rating now.
3. For the hours ahead, blend back toward the forecast at the rate its errors historically decay.

Nothing measures the surf at the Poles itself, so there is no ground truth to score against. A
one-tap rating from the watch while he is out is the proposed source.
