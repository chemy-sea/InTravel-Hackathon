# Verified Intramuros Boundary (Section 1 audit)

This document records the source and method used to verify the real Intramuros
walled-city boundary for the POI boundary audit in
`docs/kiro-maps-improvements.md` (Section 1), so future edits can re-run the
same check instead of guessing coordinates.

## Source

The boundary polygon was fetched from the **OpenStreetMap Nominatim API**,
not approximated:

```
https://nominatim.openstreetmap.org/search?q=Intramuros,Manila,Philippines&format=json&polygon_geojson=1&limit=1
```

This returns **OSM relation `103707`** — tagged `boundary=administrative`,
`addresstype=quarter`, under Manila, Capital District, Metro Manila — as a
closed 59-point polygon tracing the wall/moat perimeter. Its bounding box
(`14.5829–14.5960°N, 120.9673–120.9811°E`) and area line up with the commonly
cited figures for Intramuros: ~0.67 km² / 59–67 hectares within the walls
(Wikipedia, Britannica).

This is a materially different (and more precise) boundary than the loose
rectangular `bbox` recorded in `assets/data/pois.json` and
`assets/data/walking_paths.json`, which is just the fetch window used by
`tool/fetch_pois.dart` / `tool/fetch_walking_paths.dart` and was never meant
to represent the actual wall line.

## Method

Every candidate coordinate was tested against the polygon with a standard
ray-casting point-in-polygon algorithm (not a bounding-box check, since a
bounding box would incorrectly pass points like Rizal Park that sit inside
the bbox but outside the actual walls).

## What was audited

- `assets/data/pois.json` — every POI entry.
- `lib/services/location_service.dart` — all `_RawSite` coordinates.
- `lib/services/gate_service.dart` — all gate coordinates.
- `lib/services/route_service.dart` — all transport pickup-point coordinates.
- `assets/intravel/index.html` — the dashboard's independent `mapPin(...)`
  coordinate calls (a separate hardcoded set from `location_service.dart`,
  used only for the Leaflet map).
- `assets/data/walking_paths.json` — **intentionally not** boundary-checked.
  This file is the pedestrian route graph, not a POI/pin list; it legitimately
  includes segments outside the wall line (bridges to Binondo, esplanade
  paths, streets just outside the gates) because routes have to cross those
  to reach Intramuros' gates. The Section 1 boundary rule applies to points
  of interest / map pins, not connecting path infrastructure.

## Result

- **3 POI entries removed** from `assets/data/pois.json` for falling outside
  the verified boundary (see `_boundaryAuditNote` in that file for detail):
  `Rizal Park Musical Dancing Fountain`, `Flower Clock` (both in Rizal
  Park/Luneta, west of the walls), and `Pasig River Esplanade` (riverside,
  north of the walls).
- **1 stale coordinate corrected** in `assets/intramuros/index.html`:
  the `Baluartillo de San Jose` map pin used `[14.5882, 120.9724]`, which is
  outside the boundary. `lib/services/location_service.dart` already had the
  correct, OSM-verified coordinate for the same place (`14.5867, 120.9747`,
  OSM way 331675589) from an earlier fix that was never propagated to the
  HTML dashboard's separate pin list. The HTML pin was updated to match.
- All other checked coordinates (54 in `location_service.dart`, 4 gates, 4
  transport points, 20 remaining HTML map pins, and all remaining POIs) were
  confirmed inside the boundary.
