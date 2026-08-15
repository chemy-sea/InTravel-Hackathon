# Feature Improvement Spec — Maps & POI Batch

## Context
This batch focuses on map/location data accuracy, the location details UI, the Saved (Your Hub) section, accessibility pins, and routing behavior. These changes will feed into the chatbot's knowledge layer as a final step once the underlying data is corrected.

---

## 1. POI Boundary Audit — Strictly Enforce Intramuros-Only Locations

### Problem
The POI (Points of Interest) list currently includes locations that are not actually within Intramuros (e.g. Rizal Park, the Flower Clock), which are physically outside the walled city. This is a data accuracy problem, not a guess — it needs to be verified against the real, defined boundary of Intramuros, not assumed.

### Requirements
1. THE SYSTEM SHALL determine the actual geographic boundary of Intramuros (the walled city) using a reliable reference (official maps, GIS boundary data, or verified coordinate polygon) — not an approximation or guess.
2. THE SYSTEM SHALL audit every existing POI entry against this verified boundary.
3. WHEN a POI's coordinates fall outside the verified Intramuros boundary THE SYSTEM SHALL flag it for removal or relocation (e.g. Rizal Park, the Flower Clock, and any other similarly out-of-bounds entries).
4. THE SYSTEM SHALL NOT include any location outside the Intramuros walls going forward, across all categories (not just POI).
5. THE SYSTEM SHALL present the full list of flagged out-of-bounds locations for review before deletion, so nothing is silently removed without confirmation.

### Acceptance Criteria
- [ ] A verified Intramuros boundary reference is defined and documented in the codebase/data layer.
- [ ] Every POI is checked against it, not assumed correct.
- [ ] Rizal Park, Flower Clock, and any other out-of-bounds entries are flagged and reviewed.
- [ ] Final POI list contains only locations within the verified boundary.

---

## 2. Map Tap — Centralize "View Details" Popup

### Problem
When tapping a location pin directly on the map, the "View Details" card/popup appears off-position, which looks visually broken.

### Requirements
1. WHEN a user taps a location pin on the map THE SYSTEM SHALL display the "View Details" popup in a centralized position on screen (not off-center or overlapping edges).
2. THE SYSTEM SHALL ensure the popup placement adapts correctly across different screen sizes.
3. THE SYSTEM SHALL keep the tapped pin visible/in view when the popup appears (e.g. adjust map camera slightly if needed so the pin isn't hidden behind the popup).

### Acceptance Criteria
- [ ] Popup appears centered/well-positioned regardless of where on the map the pin was tapped.
- [ ] Works correctly across different device sizes.
- [ ] Pin remains visible when popup is shown.

---

## 3. Add Reviews to Locations

### Requirements
1. THE SYSTEM SHALL add a minimum of 5 and maximum of 10 reviews per location across all categories.
2. THE SYSTEM SHALL ensure reviews are realistic and sensible in tone/content for the type of location (e.g. a historical site vs. a restaurant should have contextually appropriate review content).
3. THE SYSTEM SHALL include standard review fields (rating, reviewer name, review text, and optionally date) consistent with the app's existing review data structure, if one exists.

### Acceptance Criteria
- [ ] Every location has 5–10 reviews.
- [ ] Reviews are contextually sensible per location type.
- [ ] Review data structure matches existing app patterns.

---

## 4. Your Hub (Saved) — Multi-Select Bulk Delete

### Problem
Users can currently only manage saved itineraries one at a time; there's no way to delete several at once.

### Requirements
1. WHEN a user long-presses (or uses an equivalent "select" trigger) on a saved itinerary in Your Hub THE SYSTEM SHALL enter a multi-select mode.
2. WHILE in multi-select mode THE SYSTEM SHALL allow the user to tap additional itineraries to add/remove them from the selection.
3. WHILE in multi-select mode THE SYSTEM SHALL display a visible count of selected items and a delete action.
4. WHEN the user confirms deletion THE SYSTEM SHALL remove all selected itineraries and show a confirmation prompt before the deletion is finalized (to prevent accidental mass deletion).
5. THE SYSTEM SHALL allow the user to exit multi-select mode without deleting anything (cancel action).

### Acceptance Criteria
- [ ] Long-press (or equivalent) enters multi-select mode.
- [ ] Users can select/deselect multiple itineraries.
- [ ] Selected count is visible.
- [ ] Confirmation step exists before bulk delete executes.
- [ ] Cancel option exits without deleting.

---

## 5. Saved Behavior & Heart Icon Redesign

### Problem
Locations are currently being auto-added to Your Hub / Saved by default, which shouldn't happen. Also, the heart icon used for saving doesn't look aesthetically fitting for the app.

### Requirements
1. THE SYSTEM SHALL NOT save any location to Your Hub / Saved by default.
2. THE SYSTEM SHALL only save a location when the user explicitly performs the save action.
3. THE SYSTEM SHALL replace the current heart icon with a different icon better suited to the app's visual style (e.g. bookmark, star, or a custom icon consistent with existing iconography) — exact icon choice to be confirmed with design preferences before implementation.
4. THE SYSTEM SHALL apply the new icon consistently everywhere the save action currently appears (location cards, details view, map popups, etc.).

### Acceptance Criteria
- [ ] No location appears in Your Hub / Saved unless manually saved by the user.
- [ ] Old heart icon is fully replaced.
- [ ] New icon used consistently across all save touchpoints.

---

## 6. Accessibility Options — Random Sensible Pins with Small Info Notes

### Problem
Accessibility filter options (other than Cafe, which already has enough data) need supporting pinned locations within Intramuros, with lightweight informational notes instead of full detail views with photos.

### Requirements
1. THE SYSTEM SHALL add randomly-placed but sensible pins for all accessibility options except Cafe (which is already sufficiently populated).
2. THE SYSTEM SHALL ensure all added pins fall strictly within the verified Intramuros boundary (see Section 1).
3. THE SYSTEM SHALL base pin placement on realistic patterns of where such accessibility features are typically found (e.g. rest areas near plazas, braille signage near museums/historical markers), even if the specific location is generated rather than independently verified.
4. WHEN a user taps an accessibility pin THE SYSTEM SHALL display a small note directly above the pin (not a full detail card, and no photo required) describing the relevant accessibility feature — e.g. "Bumpy road ahead," "Braille signage available," "Rest area."
5. THE SYSTEM SHALL keep this note lightweight and dismissible (tap elsewhere to close).

### Acceptance Criteria
- [ ] All non-Cafe accessibility options have pins within Intramuros only.
- [ ] Pin placement makes contextual sense for the feature type.
- [ ] Tapping a pin shows a small note above it (no photo, no full detail view).
- [ ] Note is dismissible.

---

## 7. Smart Re-Routing

### Problem
Navigation currently doesn't intelligently adjust when a user deviates from the planned route.

### Requirements
1. WHEN a route is calculated THE SYSTEM SHALL select the quickest available path by default.
2. WHEN a user deviates from the current route (e.g. takes a wrong turn) THE SYSTEM SHALL detect the deviation and calculate a new route from the user's current position.
3. WHEN a new route is calculated after a deviation THE SYSTEM SHALL inform the user how much slower (in minutes) the new route is compared to the original, if applicable.
4. WHEN no reasonable alternate route exists forward from the deviation point THE SYSTEM SHALL instruct the user to make a U-turn as the fallback option, and this SHALL be treated as a last resort rather than a first suggestion.
5. THE SYSTEM SHALL prioritize forward-path rerouting over suggesting a U-turn whenever a viable alternate route exists.

### Acceptance Criteria
- [ ] Default route selection favors quickest path.
- [ ] Wrong turns trigger automatic recalculation.
- [ ] User is told the time difference of the new route vs. original.
- [ ] U-turn is only suggested when no better alternative exists.

---

## 8. Feed Updated Data to Chatbot

### Requirements
1. AFTER Sections 1–7 are implemented and verified THE SYSTEM SHALL update the chatbot's knowledge layer to reflect: the corrected/boundary-verified POI list, new reviews, updated accessibility pin data, and any new saved/itinerary behavior relevant to what the chatbot can answer about.
2. THE SYSTEM SHALL ensure the chatbot does not reference any removed (out-of-boundary) locations in its answers.
3. THE SYSTEM SHALL allow the chatbot to answer questions using the new review data and accessibility notes where relevant (e.g. "which places have braille signage," "what do people say about X place").

### Acceptance Criteria
- [ ] Chatbot no longer references removed/out-of-bounds locations.
- [ ] Chatbot can answer using new reviews and accessibility note data.
- [ ] Knowledge layer update happens only after prior sections are confirmed stable.

---

## Suggested Order
1. POI Boundary Audit (Section 1) — foundational data fix, everything else depends on accurate location data.
2. Map tap popup centering (Section 2) — independent UI fix, quick win.
3. Reviews (Section 3).
4. Accessibility pins + notes (Section 6) — depends on boundary data from Section 1.
5. Saved behavior + heart icon (Section 5).
6. Your Hub bulk delete (Section 4).
7. Smart re-routing (Section 7).
8. Feed everything to chatbot (Section 8) — last, since it depends on all prior data being finalized.
