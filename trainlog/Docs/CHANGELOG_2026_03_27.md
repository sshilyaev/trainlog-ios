## 2026-03-27

### UI Foundation
- Introduced `MainSheet` as a unified sheet header and presentation container.
- Standardized sheet presentation via `mainSheetPresentation` presets.
- Unified sheet title behavior and spacing for consistent center alignment.

### Post-registration CTA flows
- Reworked trainee and coach onboarding CTA screens with clearer value messaging.
- Added CTA for achievements from trainee onboarding.
- Fixed post-registration onboarding trigger for coach profile creation.
- Updated membership offer screen to remove misleading decorative block and simplify actions.

### Personal records ("My Achievements")
- Improved record creation flow and step UX.
- Added activity catalog type filters (e.g. strength/cardio/endurance) with search compatibility.
- Updated empty state behavior and visibility rules for mode/search/add controls.
- Added contextual guide access in hero area.

### Measurements, goals, and date picking
- Unified date selection UI to shared row pattern (`FormRowDateSelection`) with "Указать дату" behavior.
- Applied unified date row and calendar sheet flow across measurement/goal/record/membership/event forms.
- Added dedicated calendar sheets where date was previously inline compact picker.

### Coach area
- Fixed newly created trainee visibility race by strengthening force-network reload path.
- Updated trainees toolbar icon layout (separated sort/search actions).
- Hid statistics filter/value toggles when there is no data.

### Design system updates
- Refreshed custom confirmation dialog style to match app visual language.
- Reworked toast style (lighter, no close button, lower screen position).
- Increased empty-state icon sizes for better visual balance.
- Updated action button border rendering to corner-emphasis style (top-left and bottom-right fade).

### Developer UI Kit
- Expanded UI Kit with:
  - full component catalog sections,
  - complete AppDesign token list,
  - AppIconSize showcase,
  - all AppColors/EventColor tokens,
  - full AppTablerIcon token list with source/mapped/asset names.

### Notes
- Build verification completed successfully after these changes.
