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
that is the day worth surfing. The hub sends every day of the forecast (`days` in `surfLive`), each
one those twelve hours, plus that day's water at local noon for the grid pane's plot. Outside in: the RATING band, the RAIN band, then two numbers an hour — the height that breaks, to a
decimal, and the wind, bare because its colour is its direction.

THE INNER BAND IS RAIN, NOT WAVE HEIGHT. The height is already written as a figure at every hour, so a
band repeating it spends the ring's second ring saying the same thing twice; rain is the one thing on
the feed that nothing else on this face carries. It comes from the hub's weather card verbatim
(`weather.pop`, one base-36 character an hour indexing `weather.colors`, `.` for no reading), so the
watch and the hub cannot disagree about a colour. Two consequences to expect rather than debug: the
rain runs SEVEN days where the surf runs ten, so the last days of the ring have no inner band, and
hours already past carry no reading either, which is why this morning's early hours are bare.
The exact height earns its place because Surfline's range is coarse: a whole morning reads `1-2 ft`
while the raw numbers climb 1.5, 1.6, 1.5 through it. Swell PERIOD is not drawn per hour — it moves a
median of one second across a daylight day here, and 10-12s and 12-20s hours rate the same, so twelve
of them would be one number written twelve times.

IT IS A CLOCK FACE. TWELVE SLOTS, NEVER ANOTHER NUMBER — an hour is a twelfth of the ring and sits
where a clock puts it: 6 at the BOTTOM, 9 at the LEFT, 12 at the TOP, 3 at the RIGHT. It is worn on a
wrist beside a watch face, and any other count makes a position stop meaning a time. 6am and 6pm
SHARE the bottom, exactly as they do on a clock, and that shared point is the day's boundary — which
is why it lands on the vertical with nothing contrived to put it there. An hour owns the block from
its own mark to the next, so the twelfth runs 5pm to 6pm and the ring covers 6am to 6pm while only
6am through 5pm carry marks.

THE BOUNDARY IS A GAP, cut from the END of the day rather than centred on the mark: 6am begins exactly
at bottom centre, because the clock position is the point of the ring, so the missing arc sits to the
RIGHT of it, taken out of the last hour's tail. Ten points of arc, converted from the border's own
perimeter so it is the same gap on any size of watch.

THE SEAM-KILLING OVERRUN MUST NOT SPILL INTO IT. Strokes overrun each other by a hair because abutting
strokes on fractional pixels antialias into pale seams — and left unclamped the last stroke paints
over the boundary, showing a ten-point gap as a hairline. It is clamped to the gap's own edge.

Flanking it, a SUNRISE clockwise and a SUNSET anticlockwise — the two sides of
the day in the one vocabulary that needs no key. Neither symbol sits ON the boundary and neither can:
6am is where the day starts, so the first hour's own figures and the join are the same point. They go
in the clear arc either side instead. The line stops outside the numbers, because drawn through them
it is a strikethrough on a figure.

EACH HOUR'S NUMBERS SIT AT ITS OWN MARK, the leading edge of its block, which is where the spoke
stands at that hour — so the reading, its block and the clock hand all agree. Centring the block on
the mark instead puts the last half hour of the day before the first half hour of it, and leaves no
edge at the bottom to call a boundary.

THE BAND IS ONE CONTINUOUS RIBBON, not twelve tiles. The colour holds flat across the middle of each
hour and crosses to the next over a fade centred on the join, so a morning that improves reads as a
sweep. Drawn as 144 short strokes with an interpolated colour rather than a gradient, because Canvas
will not run a gradient along an arbitrary path — and each stroke overruns the next by a hair, since
abutting strokes on fractional pixels antialias into exactly the pale seams the fade exists to
remove. The day's own boundary never fades: that edge stays hard.

THE NOW-BAR STOPS AT 0.84 of the radius. The sea, swell and water lines reach about 0.78 at the
sides, so a longer one strikes through them — at 3pm it lands across the water temperature.

THREE PANES THAT PAN, and the GRID is the middle one and the default — the week is the question the
app is opened with, and the other two hang off it: the day's own detail LEFT, the rain RIGHT. All
three are laid out side by side in a row that is offset to bring one into view, so a swipe drags the
next in from the edge rather than swapping it in place. Clipped to `paneW`, which is the width of the
CLEAR MIDDLE — the ring's hourly figures sit about 45 points in from each edge and a wider pane paints
over them as it slides past.

THE RAIN PANE is seven columns, not ten: the rain forecast is shorter than the surf one, and padding
it to match would say the week ends in drought rather than that nothing is known. It draws ALL 24 HOURS where the surf grid draws only the twelve worth surfing: rain before dawn or at
ten at night still decides something. Under each column is that day's HIGHEST chance across the whole
day — the number anyone actually asks of a rain forecast, and higher than a daylight-only reading
whenever the weather comes overnight —
and under that the air HIGH over its LOW, unlabelled and without units, because on a column already
headed by its day and footed by a percentage, a bigger number over a smaller one in the seventies
reads as nothing else.

The air figures are taken over the WHOLE local day (`air_hi` / `air_lo`, computed in `surfLive` from
the snapshot's `aT`), not over the drawn hours: the day's low is a pre-dawn number, and reading it off
6am onward reports the morning's low as the day's.

TWO GESTURES, TWO INDEPENDENT THINGS. The CROWN picks the DAY — today out to the end of the forecast
— and the ring redraws for it. A horizontal SWIPE picks what the MIDDLE says, and nothing else:
the live readings, or every day at once as a grid. Either pane works on any day, because the two
never touch. A swipe rather than a `TabView`: the crown is already bound to this view and watchOS's
paging styles want it for themselves.

IT OPENS ON TODAY, always. Late in the evening that is a ring whose twelve hours have all been and
gone, and it is still the day to open on — the crown is one turn away from tomorrow, and a face that
quietly shows a different day than the one asked for is worse than one showing a finished day
honestly.

WHERE NOW IS COMES FROM THE HUB (`now_hour`), not the device: `Calendar.current` on the watch is the
PHONE's timezone, so a spoke placed locally lands on the wrong hour the moment he travels.

THE CROWN'S SPEED IS ITS RANGE. Bound straight to the day index, ten days is the crown's whole travel
and a flick lands three days from the one you wanted; `perDay` gives each day four detents. The day
label carries its DATE as well as its weekday (`FRI 9/25`), because Friday comes round twice in ten
days and the span crosses a month. A long press hides the edge numbers for the bands alone; a tap refreshes and goes back to today —
never changing the pane, which is where he put it.

THE GESTURES' RESOLUTION ORDER IS LOAD-BEARING. A plain `.onTapGesture` beside `.onLongPressGesture`
loses most FIRST taps: the long press claims the touch and waits out its duration before anything else
is asked. They are an `ExclusiveGesture` with the tap first, and the drag is SIMULTANEOUS rather than
in that chain, because a gesture that must fail before a tap is considered delays every tap by its own
threshold. The crown's own green accessory is hidden (`digitalCrownAccessory(.hidden)`) — it is a
scroll position and there is nothing here to scroll.

THE GRID PANE is the hub's own heat map turned to fit a square screen — a day per COLUMN, an hour per
row, the rating band over the height band on the same blue, and the water across the same columns.

EARLY AT THE BOTTOM, LATE AT THE TOP: 6am the bottom row, 5pm the top. That is the ring's own
orientation, since 6 o'clock is the bottom of a clock, and the hub's heat map's (`y = base + GRID_H -
h * ch` in cards/surf.js). Running it the other way makes the two panes of one screen disagree about
which end of the day is which, which is exactly how it reads as upside down.

ONE CONTINUOUS FIELD OF COLOUR. Cells touch; the only gaps are the two that carry meaning — before
each SUNDAY so a week is countable, and at NOON so the middle of the day is findable without counting
rows. A gap everywhere is a grid ruled in black; a gap in two places is a pair of landmarks. Each
column is headed by its weekday letter, today's in full white.

THE WATER'S RANGE IS WRITTEN IN THE BLANK at the right, high and low. The marine model stops a few
days short of the surf forecast, so the last columns carry no line — and a line with no scale beside
it says only that the water changed, not to what.

THE CROWN'S DAY IS OUTLINED, NOT STRUCK THROUGH. A line down the middle of a column covers the cells
it is pointing at and reads as an artefact of the drawing; a box round the column says selected and
leaves every cell visible. That box is the only thing tying this pane to the crown, since the ring is
out behind the numbers at the edge.

`days` is ONE array and it is both the ring and the grid, so the two cannot disagree about a day.

The middle is the measured wind and the sea, and the wind's direction is an ARROW pointing where it
BLOWS (`dir_to` in the feed) — a compass point has to be turned around in your head first. There is
no unit and no gust beside it: the big figure on a surf face is knots, and the arrow and the reading's
age stack next to it instead. The age shows only when the hub says `stale`, which it judges against
the reporting station's cadence — the dock reports every six minutes and the KNRB fallback hourly, so
one threshold would flag a current hourly report through most of every hour of an outage. The water
temperature reads at the same size as the sea and swell lines and in its own colour (`water_color`,
cold blue to warm orange, computed by `waterColor` in the hub and spread across the 51-88F Mayport
itself runs rather than a generic wetsuit chart's range); the `/surf` page's Water card draws the
same number the same way. Nothing but the bands touches the edge, because
text under them is unreadable on both.

THE MODEL RIDES AS A GHOST BEHIND THE MEASUREMENT, and only when the two genuinely disagree. The hub
decides that (`diverged` in `lib/livewind.js`) on the HALF-HOUR AVERAGE, so a gust cannot raise it and
a divergence that has not held is not one; it qualifies on 4 kt of speed, 40 degrees of direction, or
a sector disagreement at any size, each of which is above this spot's own noise. The watch then draws
a dim arrow at the direction the model expected and its speed under the live figure.

It says WHICH WAY and BY HOW MUCH the forecast is wrong, which an indicator light cannot. And it ADDS
rather than replaces: in agreement the ghost is simply absent.

THE MIDDLE IS LIVE WHATEVER DAY THE RING IS, which is why NO SPOKE ACROSS ANY HOUR is what says the
ring has rolled over to tomorrow, and nothing writes it in words. A label is the wrong instrument for
it wherever it is put: placed anywhere near the middle it is read as qualifying the measured wind and
sea, which are never tomorrow's, and the top of the screen is under the bands and across the noon
numbers. A clock hand pointing at no hour already says these are not the hours you are in.

Water Lock is Apple's, not ours: an app can stop its own touches but not watchOS's gestures, so a
half-measure inside the app was worse than the real thing (it cost double tap; Apple support 108413).

Check it in the simulator rather than guessing, which takes about a minute:

    xcrun simctl boot <watch udid>            # xcrun simctl list devices available | grep Watch
    xcodebuild -project Gnarcast.xcodeproj -scheme GnarcastWatch -destination "id=<udid>" \
      -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
    xcrun simctl install <udid> build/Build/Products/Debug-watchsimulator/GnarcastWatch.app
    xcrun simctl launch <udid> com.jaredgantt.surf.watchkitapp
    xcrun simctl io <udid> screenshot /tmp/watch.png

## The watch widgets — one extension, two different things

`WatchWidgets/` ships both, and they are NOT the same API with different shapes:

- A **CONTROL** (`ControlWidget`, watchOS 26+) reaches Control Center, the Smart Stack and an Ultra's
  Action button — three surfaces for one declaration. It is drawn by the SYSTEM from a `Label`: a
  symbol and some text, and there is no way to put a gauge, a colour or a reading of ours in it. So
  the control opens the app and does nothing else. The two kinds that exist are a BUTTON and a TOGGLE;
  nothing else. A control cannot hold stored properties either, since the system instantiates it.
- A **COMPLICATION** (`Widget` + `StaticConfiguration`) is a view of OURS on the watch face, so this
  is where a reading goes: the rating as colour with the height inside it, in the same grammar as the
  app's own ring. Four families — circular, corner, rectangular, inline.

THE COMPLICATION REFRESHES HOURLY, and that is a budget rather than a preference: watchOS grants a
complication a small number of background refreshes a day and refuses the rest, so asking every few
minutes leaves the face STALER than asking hourly. The forecast moves on a six-hour capture anyway.

Registering `com.jaredgantt.surf.watchkitapp.widgets` came first — an unregistered bundle id fails the
archive with a missing-profile error that names the profile rather than the id.

## Builds

`tools/testflight.sh` from this Mac, first. `.github/workflows/testflight.yml` is the backup for when
the Mac is away. Both number builds by UTC time; see README.

TestFlight has a DAILY UPLOAD CAP — about 21 builds in a rolling day here, and the refusal is
`Upload limit reached. The upload limit for your application has been reached.` Verify layout in the
simulator and batch changes into one upload rather than shipping a build per adjustment.

`tools/devinstall.sh` installs straight onto the phone over USB, no TestFlight. Three things have to
be true once per device and each fails silently in its own way:

- **The device is registered in the developer account.** A replacement handset is a NEW udid however
  identical it looks, and every profile refuses it until it is added. The error names the profile, not
  the device, so it reads as a signing problem.
- **Developer Mode is on**, on the phone AND on the watch, and the iOS device support files for its
  OS version are downloaded (Xcode offers this on first connect; they run to gigabytes).
- **THE BUILD NUMBER MUST EXCEED WHAT TESTFLIGHT LAST PUT ON THE WATCH.** `project.yml` carries
  `CURRENT_PROJECT_VERSION: "1"`, so a plain `xcodebuild` produces build 1; the watch app is then a
  downgrade from the TestFlight copy and watchOS refuses it WITHOUT AN ERROR — the Watch app's install
  spinner goes all the way round and the app never appears. The script stamps the same UTC timestamp
  testflight.sh does, which keeps the two paths monotonic.

A dev-signed build registers a SANDBOX APNs token, so it cannot receive push from the hub. It does not
matter for Gnarcast, which sends none; it would silently break StatusHub.
