# Performance evidence (Flutter DevTools)

## Issue observed
During interaction (scrolling and typing in search), DevTools showed frame spikes/jank when extra work happened during rebuilds.

## Cause
Distance calculations + sorting can become expensive if they run repeatedly inside build/rebuild.

## Optimisation implemented
- Cache park distances after location is retrieved.
- Maintain a pre-sorted list of parks and reuse it during rebuilds.
- Only recompute distances/sort when the location changes.

## Evidence
Screenshots:
- docs/screenshots/performance_before.png
- docs/screenshots/performance_after.png
