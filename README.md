# surf-app

The surf app: an iPhone app and its Apple Watch companion for Mayport Poles — the surf heat map,
the live readings (measured wind, buoy swell) beside what Surfline's model says, and a short-term
forecast that folds the live readings in.

Its own product, so its own repo. It shares a backend with StatusHub rather than code:

| piece | where |
|---|---|
| Surfline forecast capture, NDBC water/wind archive | `surf-report` (the Pi's crontab) |
| live wind, surf alarm, the APIs this app reads | `status-hub/server` on Fly (`jared-status-hub`) |
| the iPhone and watch apps | here |

**Gnarcast** in App Store Connect (app id `6814910411`, SKU `surf-app`). Bundle ids
`com.jaredgantt.surf` (iPhone) and `com.jaredgantt.surf.watchkitapp` (the watch app, shipped inside
the iPhone app, which is why one record covers both). TestFlight group `internal_main` has access to
every build; a build uploaded with no group reaches no one.

Open work is in [docs/TODO.md](docs/TODO.md).
