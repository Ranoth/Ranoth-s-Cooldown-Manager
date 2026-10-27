# Ranoth's Cooldown Manager

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

Only RCM-drawn borders are affected, not Blizzard frame artwork, glows, or
internal class-resource dividers. Geometry is checked on layout/visibility/style
changes, not every frame. Unchanged geometry skips rendering, and any extra
edge textures needed for partial contacts are pooled and reused.
Shared-border calculations never run during combat; requests are deferred
and geometry is refreshed after combat ends. Existing shared geometry remains
in place meanwhile. Unreadable secret geometry is excluded from that refresh,
leaving ordinary borders until readable geometry becomes available.
Shared edges use a common border layer within each frame strata so neighboring
icon artwork and bar fills cannot cover a seam. Border geometry is aligned to
physical display pixels before splitting edges, with thickness rounded to the
nearest whole pixel (minimum one). This avoids fractional-pixel seams changing
appearance with UI scale or position, without moving the icons or bars.
Display resolution and UI scale changes invalidate the cached geometry.