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

## Builds

`tools/testflight.sh` from this Mac, first. `.github/workflows/testflight.yml` is the backup for when
the Mac is away. Both number builds by UTC time; see README.
