# Ranoth's Cooldown Manager

## Source organization

`src\Core` contains shared addon services; `src\Modules` contains feature
implementations. Custom bars are grouped under `src\Modules\Bars`:

- `Common.lua`: shared frame, border, text and resource-selection helpers.
- `CastBar.lua`: cast/channel state, spell icon, interrupts and previews.
- `PrimaryPower.lua`: primary-resource or mana rendering.
- `ClassPower.lua`: segmented resources, runes, shards and moved primary power.
- `Bars.lua`: the existing Bars API, lifecycle, Blizzard-frame suppression and
  single coordinated event router.

`src\Modules\Bars\Init.xml` specifies their loading order. The options companion
mirrors this folder with shared controls, per-bar menus and a menu aggregator;
it remains loaded on demand. All three bars still use the existing `Bars`
settings namespace and `CastBar`, `Mana` and `ClassPower` profile keys, so
existing profiles and feature integrations require no migration.

Icon skinning is grouped under `src\Modules\Skin`:

- `Common.lua`: the Skin module, defaults and shared styling state.
- `GlowGeometry.lua`: per-side seam clearance, pixel alignment and native artwork margins.
- `NativeEffects.lua`: native-effect fitting, layering and pooled-effect hooks.
- `Text.lua`: count/countdown lookup, font overrides and restoration.
- `IconStyle.lua`: icon crop, masks, swipe textures and borders.
- `ActiveAlpha.lua`: viewer opacity ownership and active-icon overrides.
- `ItemCounts.lua`: Healthstone use counts and their display cache.
- `Skin.lua`: viewer reconciliation, diagnostics, profile migration and lifecycle.

`src\Modules\Skin\Init.xml` loads these components before the glow consumers.
They retain one Skin module and settings namespace; the compact Skin options
menu remains loaded on demand. This split changes code organization, not
rendering, settings or event ownership.

Custom trackers are grouped under `src\Modules\CustomTrackers`:

- `Common.lua`: module, defaults, supported groups/slots and shared frame registry.
- `Availability.lua`: player/pet spellbook checks and the combat-safe availability cache.
- `Geometry.lua`: combined viewer ordering, reserved space, sizing and tooltip visibility.
- `Frames.lua`: pooled icon construction, tooltip content and texture preservation.
- `SpellCooldown.lua`: spell/charge durations and secret-safe desaturation.
- `ItemCooldown.lua`: equipped-slot and bag-item cooldowns, counts and item-data requests.
- `Entries.lua`: tracker registration, validation and legacy buff-entry cleanup.
- `CustomTrackers.lua`: refresh coordination, cooldown dispatch and lifecycle/events.

`src\Modules\CustomTrackers\Init.xml` specifies their loading order. The existing
CustomTrackers API, settings namespace, frame pool and load-on-demand options
menu remain intact; no profile migration or rendering changes are introduced.

Shared borders are grouped under `src\Modules\Borders`:

- `Common.lua`: the Borders module, defaults and shared registration state.
- `Registry.lua`: registration, glow seam clearance, overlay layering and diagnostics.
- `Geometry.lua`: pixel-aligned seams, mixed-width ownership and non-overlapping rectangles.
- `Rendering.lua`: texture reuse, shared border levels and original-edge restoration.
- `Borders.lua`: combat-safe refresh coordination, profile migration and lifecycle/events.

`src\Modules\Borders\Init.xml` loads these components before border consumers.
They retain one Borders module, settings namespace and load-on-demand options
menu. Shared-border geometry, glow clearance and event ownership are unchanged.

Stack layout is grouped under `src\Modules\Layout`:

- `Common.lua`: the Layout module, defaults and viewer/bar resolution.
- `Ordering.lua`: ordered keys, stack moves, key lookup and diagnostics.
- `Frames.lua`: the container, pooled slots and debug overlays.
- `Visibility.lua`: managed-frame strata, restoration and alpha suppression.
- `Placement.lua`: sizing, cycle-safe attachment and placement around the anchor.
- `Layout.lua`: coalesced combat-safe requests, profiles and lifecycle/events.

`src\Modules\Layout\Init.xml` specifies their loading order. The anchor viewer
remains owned by Blizzard's Edit Mode. The existing Layout settings namespace,
public API and compact companion menu are unchanged; the menu stays loaded on
demand and does not need to mirror the runtime components.

Icon layout is grouped under `src\Modules\IconLayout`:

- `Common.lua`: the IconLayout module, defaults and combined-content dimensions.
- `Geometry.lua`: scale-aware measurement, active ordering, stride and row grouping.
- `Anchors.lua`: original-anchor preservation, restoration and incremental attachment.
- `Placement.lua`: centered, compact and combined native/custom tracker grids.
- `IconLayout.lua`: viewer/item hooks, settings controls and lifecycle/events.

`src\Modules\IconLayout\Init.xml` specifies their loading order. The existing
IconLayout API, profile keys, Blizzard anchor ownership and combat behavior are
preserved. The companion's compact IconLayout menu remains loaded on demand
and uses the same public setting methods.

Proc glows are grouped under `src\Modules\Glow`:

- `Common.lua`: the Glow module, defaults, ownership and session-only preview state.
- `Dashes.lua`: the reusable animated-dash renderer shared with NativeGlows.
- `Proc.lua`: activation, Blizzard-alert suppression and selected-effect previews.
- `Layers.lua`: border-layer reconciliation and diagnostics.
- `Glow.lua`: viewer ownership, cached geometry, profiles and lifecycle/events.

`src\Modules\Glow\Init.xml` loads the components after Skin and before NativeGlows.
The existing Glow API, shared dash functions, settings namespace and companion
menu remain unchanged. The menu still combines proc and native-effect settings
per viewer and loads only on demand.

## Runtime performance

Viewer and resource changes are event-driven; layout notifications are merged
per frame. Spell/charge cooldown events update only spell trackers, while bag
cooldown events update equipped and bag-item trackers. Manual and profile
refreshes still reconcile all tracker kinds.

Animations and cooldown/resource interpolation retain their active-only,
bounded callbacks, including secret-safe cooldown evaluation. There is no
addon-wide idle ticker. Stopped glow tests keep their reusable frames but do
not scan viewers; unchanged border refreshes do not restyle glow effects.

## Settings loaded on demand

The runtime addon loads normally. `/rcm` (or **Open settings** under
**Settings > AddOns > Ranoth's Cooldown Manager**) loads the options companion
on first use. All feature menus and profiles remain available. The first open
must be outside combat; after loading, the interface stays in memory until
reload or logout. Closing the window does not unload it.

Release packages install two sibling folders under `Interface\AddOns`:

```text
Ranoth-s-Cooldown-Manager\
Ranoth-s-Cooldown-Manager_Options\
```

Keep both installed. Opening settings automatically enables the companion for
the current character if it is disabled. The companion depends on the runtime addon, shares its
database, and has no separate saved variables. The runtime keeps profile
callbacks and applies saved settings even when the companion has never loaded.
Missing companions or other loading failures produce a chat error when opened.

For development, the companion's sources live in the repository's
`Ranoth-s-Cooldown-Manager_Options` subfolder. Copy that subfolder to a sibling
addon folder, or create a sibling directory junction pointing at it. The release
packager performs this move automatically. Its deferred library includes refer
to the runtime addon's bundled libraries, so both folder names must be preserved.
Restart WoW after first adding the companion so the client discovers its TOC.

AceGUI, AceConfig and AceDBOptions are no longer loaded by RCM at login.
Other addons may still load shared copies of those libraries, so the exact
memory saving depends on the rest of the UI. To check the cold state before
opening RCM settings, run:

```lua
/dump C_AddOns.IsAddOnLoaded("Ranoth-s-Cooldown-Manager_Options")
```

It should be false after login/reload and true after opening settings.

## Custom trackers

Open RCM settings and select **Custom trackers**. Choose **Spell cooldown** and
enter a spell ID, or choose **Equipped item cooldown** and select an equipment
slot. Select an icon group, then click **Add tracker**. Each tracker has enable,
group, position, and removal controls. Settings are saved with the RCM profile.
For consumables, choose **Bag item cooldown** and enter an item ID.

Spell trackers have **Hide unavailable ability** enabled by default, including
existing trackers. RCM checks the player and current pet spellbooks (including
override spells) outside combat, and hides abilities absent from both. For
example, Suffering and Devour Magic follow the currently summoned pet. Hidden
unavailable abilities do not reserve icon slots or stack height. Spellbook,
specialization and pet changes refresh the cached result; during combat the
last result is kept until combat ends. Turn the option off for spell IDs you
want displayed regardless of spellbook membership. Item and equipment trackers
are unaffected.

Hover tooltips on custom trackers follow their group's Cooldown Manager
tooltip setting, and mouse clicks pass through them like native icons.

Custom trackers play the ready flash at the end of their cooldown, following the
destination group's **Ready flash** setting: Blizzard's flipbook look by
default, or the custom square when enabled. Spells, charges, bag items and
equipment use the same cooldown rules as native icons (the GCD alone never
flashes).

Examples:

- Soulburn: `385899`, **Spell cooldown**, **Essential cooldowns** or
  **Utility cooldowns**. This tracks the spell cooldown, not its buff.
- Belt: **Equipped item cooldown**, **Waist (belt)**, **Utility cooldowns**.
- Trinket: **Equipped item cooldown**, **Trinket 1** or **Trinket 2**.
- Goblin Glider Kit: **Bag item cooldown**, Item ID `109076`.

Bag-item trackers use `C_Item.GetItemIconByID` and `C_Item.GetItemSpell` to
resolve the item icon and use-spell ID. Their cooldown comes from
`C_Item.GetItemCooldown`, not the spell cooldown, so item/category cooldowns
remain authoritative. Quantity is the carried stack count, excluding bank and
account-bank stock. At zero, the icon stays visible, desaturated, with `0`.
Custom tracker count text renders behind the cooldown countdown.
Bag changes and item cooldown events update it; uncached item data is requested
asynchronously. Hovering shows the item tooltip. Items without an on-use cooldown
can display quantity but do not gain a fabricated spell timer.

Equipment trackers follow the item currently equipped in the selected slot:
their icon, tooltip, and cooldown update after equipment changes. Empty slots
hide their icon. Item cooldowns use the equipment slot's cooldown rather than
the item's buff or associated spell, and exclude GCD-only cooldowns. Slots without
an active use can still show an icon but normally have no cooldown to display.
Restricted item cooldown data is reported rather than read in Lua.

Custom buff tracking has been removed because spell-ID lookup cannot identify
secret buffs in combat. Existing custom buff entries are removed with a notice
when their RCM profile is loaded; spell cooldown entries are preserved. Blizzard's
native buff tracking and its RCM styling are unchanged.

Custom icons inherit the destination group's RCM skin and native icon size.
They also use Blizzard's rounded mask, frame artwork, cooldown swipe and
viewer-specific countdown font by default. Square icons, zoom, borders, charge
text styling, countdown outlines and timer visibility follow the destination
viewer, including after moving a tracker or switching profiles.
Changing a tracker's group applies the destination skin immediately, without
requiring a reload or waiting for the viewer to refresh.
Cooldown and equipment texture updates preserve the skin's crop, and unchanged
textures are not reassigned.
For skin troubleshooting, `/rcm trackerskin` prints native/custom icon crop,
mask, font and applied-viewer state without reapplying or changing the skin.
Custom countdown and charge text inherit the destination native icon's font
baselines before RCM font overrides are applied. This also replaces explicit
font sizes left over from a previous viewer.
Moving a tracker also clears its previous viewer's per-icon opacity override,
then applies the destination viewer's opacity policy.
Icons are desaturated while on cooldown and return to full color when ready.
GCD-only cooldowns do not desaturate icons; charge-based spells stay colored
while at least one charge is available.
While a custom icon is active, RCM lays out the combined group using the viewer's
native icon scale, padding, direction, and row limit. RCM's compact spacing applies
only when **Compact icons** is enabled. Position is a slot in this combined
group, not an entry in Blizzard's settings. Positions beyond the last icon append
in ascending order; equal positions use tracker creation order.
Stack space is reserved for the combined
native and custom icon count, including empty equipment slots, to avoid combat
overlap. Custom trackers that fit in existing rows do not reserve an extra row.
Bars configured to follow the anchor viewer's width use the combined icon row
width, including custom trackers. Fixed-width bars are unaffected.
Disabling or removing the trackers releases that space.

These are addon-owned icons: they do not register new Blizzard cooldown IDs,
change Blizzard's item pools, or add entries to Blizzard's positioning menu.

## Healthstone charges

**Icon skin > Healthstone charges** controls remaining-use text for Healthstones
and Demonic Healthstones across all viewers with one profile-wide toggle.
The text still uses its viewer's stack text styling. Existing profiles keep
charges disabled if any of their old viewer-specific toggles was disabled.

## Custom primary power / mana bar

The custom primary power / mana bar is enabled by default. You can switch
between it and Blizzard's bar in **Bars**; explicitly saved choices remain
unchanged. It displays the current primary resource, or mana when primary
power is moved to the class resource bar.

## Custom cast bar

The custom cast bar is enabled by default. In **Bars > Cast bar**, you can
switch between **Custom bar** and Blizzard's bar; explicitly saved choices
remain unchanged. **Show spell icon** is enabled
by default and places the currently cast or channeled spell's icon inside the
left end of the bar. The icon stays square as the bar height changes, without
extending its total width. Turning it off restores the full-width bar.
The spell name is constrained to the remaining space and does not overlap the
icon or the time-left text. Cast and interrupt previews include a sample icon;
real interrupts retain the interrupted spell's icon.

The icon has independent **Icon border size** and **Icon border color**
controls (default: a black, size-1 border). With
**General > Shared borders** enabled, the internal icon/bar divider is a single
centered seam using the thicker border and the icon's color, provided both
borders are enabled; turning sharing off restores separate borders. This local divider
does not read screen-space geometry and can update safely during combat.

## Shared borders

One profile-wide **General > Shared borders** toggle controls icons and bars
together (off by default), including Blizzard bars restyled through Resource
skin. Existing profiles keep sharing enabled if either old toggle was on.
Touching bordered elements
share a single centered seam without changing their positions or sizes.
This covers icon-to-icon, bar-to-bar and bar-to-viewer icon contacts.
Cast bars and buff viewers (including custom trackers in Buff icons) are
excluded: they keep ordinary borders and full glow insets. Their visibility
and geometry can depend on restricted combat data.
The custom cast bar's internal spell-icon divider is the exception: it follows
the toggle without participating in screen-space sharing with other frames.
Different border sizes use the thicker size; the upper/left element supplies
the seam color and opacity. Gaps retain separate borders. Where a bar meets a
narrower bar or viewer, the centered seam continues across the exposed overhang
so the line does not step at the contact endpoints. Partially touching icon-only
edges keep their exposed sections. Native icon padding that overlaps border
bounds is supported as well.

Custom proc, ready-flash, pandemic and debuff effects use half the configured
border inset while sharing is enabled, matching the inward half
of a centered seam for participating viewers. Turning sharing off restores
their full border inset.
All custom and Blizzard icon glows render above every visible registered viewer
and bar border, including borders in higher frame strata and the raised
shared-border layer, without changing their inset. This includes proc glows,
pandemic glows, visual alerts, ready flashes and debuff borders. Ready flashes
remain above pandemic glows. Test previews use the same layering rules.
Custom marching ants, flash alerts, debuff borders and pandemic edges are not
clipped to their native parent's full-border inset: their shared per-side
insets determine the visible bounds, just like proc glows. Switching back to
Blizzard artwork restores native clipping, including released pooled alerts.
Custom dashes, square edges and ready flashes align their fixed bounds and
stroke thickness to physical pixels, avoiding thinner top strokes on small
or fractionally scaled icons. Animation uses cached raster geometry; no
screen-position queries are made by animation updates or in combat.
Native artwork fitting compensates for Blizzard's transparent margins:
proc frames use the native 1.4x footprint, visual alerts retain their scaled
8/9-unit padding, and debuff borders retain their 3-unit padding. These effects
and ready flipbooks use the icon's shared per-side clearance; pandemic keeps
its existing 6-unit padding and inset. Live effects and tests share this fitting.
Border refreshes and skin passes (including
incremental layout updates) reconcile effect layers without adding per-frame
geometry work.
### Testing icon glows

Under **Icon glows**, each viewer has independent test toggles for proc glows,
pandemic glows, marching ants, flash alerts and debuff borders. Essential and
Utility also have a looping ready-flash test. Tests follow the selected RCM
custom or Blizzard version, including changes made while the test is running.
Visual alerts use a sample gold alert when using Blizzard's alert color;
debuff borders use a sample Magic debuff.

Tests appear only on existing visible icons and can run together. They reuse
effect renderers and separate native preview frames without changing real
cooldowns, auras or Blizzard's live alert pool. Ready flashes repeat with a
short pause. Test toggles are session-only: turn them off to stop testing, or
reload; disabling the addon also clears them.

For unresolved proc layering issues, enable the custom proc test and run
`/rcm glowlayers`. It reports visible proc frames, their ancestor clipping flags
and neighboring RCM border layers without changing the display.
All custom effects use shared cached rendered seam bounds for per-side
clearance when native icon spacing overlaps adjacent icons: proc and visual-alert
dashes, pandemic and debuff edges, square ready flashes and tracker flipbooks.
Top/bottom clearance also follows the actual horizontal seam, including
mismatched-width bars whose border owns the full overhang. Exposed sides retain each
effect's normal inset. Border refreshes reconcile cached effect geometry.

Only RCM-drawn borders are affected, not Blizzard frame artwork, glows, or
internal class-resource dividers. Geometry is checked on layout/visibility/style
changes, not every frame. Unchanged geometry skips rendering, and any extra
edge textures needed for partial contacts are pooled and reused.
Screen-space shared-border calculations never run during combat; requests are deferred
and geometry is refreshed after combat ends. Existing shared geometry remains
in place meanwhile. Unreadable secret geometry is excluded from that refresh,
leaving ordinary borders until readable geometry becomes available.
Shared edges use a common border layer within each frame strata so neighboring
icon artwork and bar fills cannot cover a seam. Border geometry is aligned to
physical display pixels before splitting edges, with thickness rounded to the
nearest whole pixel (minimum one). This avoids fractional-pixel seams changing
appearance with UI scale or position, without moving the icons or bars.
Display resolution and UI scale changes invalidate the cached geometry.