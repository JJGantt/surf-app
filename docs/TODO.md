# Open work

## Blocked on Jared

- **The buoy fetch.** Live swell from NDBC 41112 (Fernandina, ~22 mi N) and 41117 (St. Augustine,
  ~30 mi S): each posts every 30 minutes, about 15 minutes late, with the swell and wind-wave split in
  its `.spec` file. NDBC pushes nothing, so it is a timer — every 10 minutes proposed, not yet agreed.

## TestFlight

`internal_main` exists but is empty: adding the tester account through the API was refused
("Tester(s) cannot be assigned") before the app had a build. Retry once the first build has
processed; if it still refuses, it is one click in App Store Connect's TestFlight tab.

## Signing

StatusHub's distribution certificate exists only in that repo's GitHub secrets and cannot be read
back, so this repo gets its own: the account holds one DISTRIBUTION certificate and has room for
another, which the ASC API can create from a CSR made here. The development identity is on disk
(`~/.appstoreconnect/private_keys/statushub-ci-development.p12` and its password file) and goes into
this repo's secrets as it is. Never let Xcode mint certificates (status-hub CLAUDE.md, "The build
machines sign with one permanent development certificate").

## The short-term model

Surfline's model covers days and is hours stale by morning (the 5am forecast is the 8pm run). The
model here covers hours:

1. Learn Surfline's rating as a function of its own inputs (size, swell, period, direction, wind,
   tide) from the hourly forecast archive in `surf_snapshots` / `surf_hours`.
2. Feed it MEASURED inputs — buoy swell and the dock's wind — for a rating now.
3. For the hours ahead, blend back toward the forecast at the rate its errors historically decay.

Nothing measures the surf at the Poles itself, so there is no ground truth to score against. A
one-tap rating from the watch while he is out is the proposed source.
