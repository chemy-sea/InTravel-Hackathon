# InTravel — Intramuros Walking-Tour Guide

A Flutter app that helps visitors explore Intramuros, Manila on foot — pick your entry gate, browse and filter historic sites, build a multi-stop itinerary with automatic route sequencing, get turn-by-turn walking directions, and ask an in-app AI assistant questions along the way.

## Features

- **Gate selection entry flow** — pick which of Intramuros' historic gates you're entering from; the app orients your starting point around it.
- **Navigation page** — persistent search bar plus multi-select category filters (landmarks, cafes, accessibility features, etc.) over the full site dataset.
- **Itinerary builder** — add stops from any location's details page, with:
  - **Nearest-neighbor route sequencing** — automatically orders your stops into a sensible walking order instead of visiting them in the order you added them.
  - **GPS-permission fallback** — if location access is denied or unavailable, sequencing falls back gracefully instead of crashing.
- **"Navigate Now" turn-by-turn** — one shared navigation flow launched from itinerary stops, location detail pages, and the POI map, with live position tracking and route progress.
- **In-app chat assistant ("IntraBadi")** — ask questions about Intramuros' history, prices, and get help managing your itinerary.
  - Primary backend: **Backboard.io**, with real tool-calling — the assistant can look up ticket prices, add stops to your itinerary, and create new itineraries on your behalf (always with a Yes/No confirmation before anything changes).
  - Optional fallback backend: native **Gemini** — plain conversational Q&A only (see Known Limitations below).

## Tech Stack

- **Flutter / Dart**
- **Map rendering: `google_maps_flutter` (Google Maps SDK for Android)** — this is the map engine actually wired into every map screen (navigation, itinerary route overview, POI explorer) as of this submission. `flutter_map` is present in `pubspec.yaml` but not used anywhere in the app; a full migration to it was planned but not completed in time for this build.
- **Backboard.io** for the primary AI chat backend, routed through OpenRouter to **Claude Haiku 4.5**.
- **Custom haversine/bearing-based routing** (`WalkingPathService`) for on-foot distance and direction calculations, layered with **OpenRouteService** for real street-following walking routes where available.

## Setup

1. Install dependencies:
   ```sh
   flutter pub get
   ```
2. Copy the example config files and fill in real keys:
   ```sh
   cp env.json.example env.json
   cp android/local.properties.example android/local.properties
   ```
   *(Windows PowerShell: `Copy-Item env.json.example env.json` and `Copy-Item android/local.properties.example android/local.properties`.)*
3. In `env.json`, set:
   - `BACKBOARD_API_KEY` — required for the chat assistant's primary backend.
   - `GEMINI_API_KEY` — only needed if you intend to use the Gemini fallback path (see below).
   - `ORS_API_KEY` — required for real walking-route lookups on the POI map.
4. In `android/local.properties`, set:
   - `flutter.sdk` — path to your local Flutter SDK.
   - `MAPS_API_KEY` — **required**, since `google_maps_flutter` is the live map engine. Needs a Google Cloud Console project with the Maps SDK for Android enabled and a billing account attached (required by Google even on the free tier).
5. Rebuild after adding/changing `MAPS_API_KEY` — it's baked in at native Gradle build time, so a hot reload won't pick it up:
   ```sh
   flutter clean && flutter run
   ```

None of these keys are ever committed — `env.json` and `android/local.properties` are both gitignored; only the `.example` templates are tracked.

## Known Limitations

- **The HTML dashboard (`assets/intravel/index.html`) is a separate, earlier prototype** — it's bundled as an offline asset for reference but is not the interface being submitted; the Flutter screens described above are the actual app.
- **The Gemini fallback path does not support tool-calling.** If `CHAT_PROVIDER` is switched to `gemini`, the assistant can still hold a plain conversation, but `checkPrice`/`addToItinerary`/`createItinerary` are not usable on that path — Gemini's SDK requires a `thought_signature` field on function-calling turns that isn't populated by this integration. The default `backboard` provider (used unless explicitly overridden) has full tool-calling support and is the intended path for this submission.
- **The flutter_map migration is incomplete** — `google_maps_flutter` is still the only functioning map renderer; the app requires a valid, billing-enabled Google Maps API key to show any map. If that key is missing or invalid, map screens fall back to a non-map list view rather than crashing.
- **A handful of pre-existing unit tests target a stale Gemini SDK response format** from before the Backboard migration and currently fail on outdated test fixtures, not on any actual app behavior — the real chat flow (Backboard wire format) works correctly.
- **Multi-turn pronoun resolution in chat** (e.g. asking about "that place" or "it" after mentioning a location by name) relies on the model correctly inferring context from conversation history — there's no code-level fallback if it doesn't, and this isn't covered by automated tests yet.

## Team

- Eunice Kate Belasa
- Jeremiah Joshua Esguerra
- Eljah Sabio
- Dan Rodrick Soriano

## Hackathon Context

Built for **CUTC Hackathon**, under the theme of building something we're genuinely proud of. This project pairs practical, offline-friendly travel tooling with a bit of ambition — real turn-by-turn navigation, automatic itinerary sequencing, and an AI assistant that can actually act on your behalf, all scoped to one of Manila's most historic corners.
