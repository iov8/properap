# SteadFast Jamaica visual identity and color system

Status: implemented shared foundation.

## Brand character

SteadFast should feel trustworthy, premium, warm, contemporary, and Jamaican through restraint, material warmth, strong local place language, and confident property presentation. The system avoids tourism styling, flag repetition, neon color, and oversized gold surfaces.

## Core palette

| Token | Hex | Primary meaning |
|---|---:|---|
| Deep evergreen | `#102C2A` | Brand foundation, navigation, headings, professional workspaces |
| Heritage gold | `#D8A72E` | Premium emphasis, approved highlights, restrained brand detail |
| Warm ivory | `#FBFAF6` | Primary page and card background |
| Soft sand | `#DED1B8` | Warm borders and secondary surfaces |
| Muted sage | `#D9E4DF` | Selected, successful, and quiet informational states |
| Caribbean teal | `#168C91` | Maps, location discovery, and visitor exploration |
| Charcoal | `#17201C` | Primary body copy |
| Coral | `#D96B52` | Tours, lifestyle content, and limited non-error attention |
| Error red | `#A64032` | Errors, destructive actions, and denial states only |

Supporting dark text variants are allowed where a core accent does not meet small-text contrast: gold `#8A650D` and teal `#0B6468`. These are accessibility companions, not separate brand accents.

## Coordinated expressions

### Professional workspace

- Evergreen navigation and workspace heroes.
- Ivory cards and forms on quiet warm-neutral surfaces.
- Sage for enabled, successful, selected, and informational states.
- Gold limited to active section edges, approved emphasis, headings on evergreen, and premium detail.
- Red reserved for error and destructive workflows with text or icon labels.

### House-hunting experience

- The same evergreen, ivory, charcoal, sand, and gold foundation.
- Teal leads maps, location controls, geographic grouping, and exploration.
- Gold identifies premium or featured details without becoming a page background.
- Coral is reserved for future tour and lifestyle cues, never errors.
- Property cards use generous whitespace and subdued teal/gold depth until public-safe photography is available.

The two expressions share the same foundation and status meanings. Audience-specific emphasis is limited mainly to teal and future coral use in visitor discovery, preserving the intended 80/20 relationship.

## Accessibility rules

- Charcoal on ivory: approximately `15.96:1` contrast.
- Evergreen on ivory: approximately `14.20:1`.
- Gold on evergreen: approximately `6.70:1`.
- Dark teal on ivory: approximately `6.62:1`.
- Error red on ivory: approximately `5.91:1`.
- White on Caribbean teal is reserved for large icons or controls because the pair is approximately `4.04:1`; small teal text uses the dark teal companion.
- Status always includes words, icons, borders, or structural placement in addition to color.
- Error red is never reused for lifestyle or tour content; coral is never used for destructive actions.

## Logo implementation

The supplied `steadfast logo.png` is preserved as `public/steadfast-logo.png` and used through the shared `BrandLogo` component. Because the source contains a baked pale checkerboard rather than an alpha channel, it is presented on a controlled ivory plate with multiply blending. The artwork, text, colors, and proportions are not redrawn.
