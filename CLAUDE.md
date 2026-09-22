# Working in surf-app

## Two surfaces, one feed — they change together

The phone shows the hub's `/surf` page; the watch draws `/api/surf/live` natively. Both read the same
payload, so a change to what that payload MEANS — a new field, a blended value replacing two, a label
that moves — is one change across both, in the same commit. Shipping it to one surface and waiting to
be told about the other is how they drift, and the person who notices is Jared.

The same rule reaches the hub: the payload is built in `status-hub/server.js` (`surfLive`), so a field
added there is added to `Shared/Hub.swift` and drawn in both places, or it is not added yet.

## Everything is computed by the hub

Colours, labels, compass points, the hours strip. The apps lay values out and never derive one — the
same rule status-hub works by, and for the same reason: two surfaces that each do their own arithmetic
end up disagreeing about the same number.

## The watch is the day around the screen's edge, and it does not scroll

The band follows the SCREEN'S OWN rounded-square border (`EdgeDial`), not a circle inscribed in it —
a circle wastes the corners and stops short of the bezel. It is not a clock either: the whole way
round is 6am to 6pm, 6am at the bottom, up the left, noon at the top, down the right to 6pm, because
that is the day worth surfing. The hub sends exactly those hours (`day` in `surfLive`), today's until
6pm and tomorrow's after. Outside in: the RATING band, the wave HEIGHT band on the heat map's own blue, then two numbers an
hour — the height that breaks, to a decimal, and the wind, bare because its colour is its direction.
The exact height earns its place because Surfline's range is coarse: a whole morning reads `1-2 ft`
while the raw numbers climb 1.5, 1.6, 1.5 through it. Swell PERIOD is not drawn per hour — it moves a
median of one second across a daylight day here, and 10-12s and 12-20s hours rate the same, so twelve
of them would be one number written twelve times.

EACH HOUR IS CENTRED ON ITS OWN MARK — its band segment straddles that mark by half an hour either
side, which makes 6am's wrap the path's start and end (`EdgeDial.wrapped` splits it). Laid out as
blocks BETWEEN the marks instead, 3pm's band and its numbers sit at half past three while the spoke,
which is the real clock, points at three.

THE CROWN SCRUBS the day: the spoke moves to an hour and the middle shows that hour's forecast,
letting go after eight seconds, because a watch left on 9am at four in the afternoon is lying about
now. A long press hides the numbers for the bands alone.

The middle is the measured wind and the sea, and the wind's direction is an ARROW pointing where it
BLOWS (`dir_to` in the feed) — a compass point has to be turned around in your head first. The water
temperature reads at the same size as the sea and swell lines and in its own colour (`water_color`,
the wetsuit scale from cold blue to warm orange, computed by `waterColor` in the hub); the `/surf`
page's Water card draws the same number the same way. Nothing but the bands touches the edge, because
text under them is unreadable on both.

THE MIDDLE IS LIVE WHATEVER DAY THE RING IS. The spoke exists only on today's ring, so once the ring
is tomorrow's — from 6pm — a `tomorrow` label says so, or the missing spoke reads as a fault. It goes
UNDER the live block: over it, it claims the measured wind and sea are tomorrow's, which they never
are. On a scrubbed hour it heads the block instead, because there everything on screen is the ring's
day.

Water Lock is Apple's, not ours: an app can stop its own touches but not watchOS's gestures, so a
half-measure inside the app was worse than the real thing (it cost double tap; Apple support 108413).

Check it in the simulator rather than guessing, which takes about a minute:

    xcrun simctl boot <watch udid>            # xcrun simctl list devices available | grep Watch
    xcodebuild -project Gnarcast.xcodeproj -scheme GnarcastWatch -destination "id=<udid>" \
      -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
    xcrun simctl install <udid> build/Build/Products/Debug-watchsimulator/GnarcastWatch.app
    xcrun simctl launch <udid> com.jaredgantt.surf.watchkitapp
    xcrun simctl io <udid> screenshot /tmp/watch.png

## Builds

`tools/testflight.sh` from this Mac, first. `.github/workflows/testflight.yml` is the backup for when
the Mac is away. Both number builds by UTC time; see README.
