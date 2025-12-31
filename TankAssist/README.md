# TankAssist v3.1.0

Snap-attention and uncontrolled target helper for tank classes in WoW 1.12 (Turtle WoW).

Supports: **Shaman**, **Druid**, **Paladin**, **Warrior**

## Installation

Copy `TankAssist` folder to `World of Warcraft/Interface/AddOns/`

## Commands

- `/ta` or `/sta` - Open options
- `/ta lock` - Lock HUD position
- `/ta unlock` - Unlock HUD position
- `/ta reset` - Reset all settings

## Features

### Uncontrolled Targets HUD

Shows enemies attacking non-protected group members in real-time.

- Enemy name displayed in **red**
- Friendly target name displayed in **green**
- Format: `EnemyName - FriendlyName`

The HUD only shows enemies discovered via unitID target chains (player, party, raid, pets). Each entry is backed by a valid game unitID.

**Limitation:** The addon can only detect enemies that someone in your group is targeting. Enemies that nobody is targeting will not appear in the HUD - this is a fundamental limitation of the vanilla WoW API.

### Protected Players

Click player names to toggle protection. Enemies targeting protected players are ignored and won't appear in the HUD.

### Snap Attention Key

Keybind or macro: `/run TA_Snap()` (or `/run STA_Snap()`)

**Modes:**
- **Target + Cast**: Targets the enemy and casts your snap spell
- **Target Only**: Only targets the enemy (no spell cast)
- **Cast Only**: Casts on enemy but restores your previous target

**Taunt-First Logic** (optional):
When "Attempt to taunt before snapping" is enabled:
1. Tries your class taunt first (if known, not on cooldown, in range)
2. If taunt fails, immediately casts your configured snap spell
3. All happens in a single keypress - no delays

**Spell Dropdown:**
Only shows spells your character has actually learned. The list is filtered based on your class and what's in your spellbook.

### Target Priority

- **Prefer furthest enemy**: Snaps to the enemy furthest from you
- **Prefer nearest enemy**: Snaps to the closest enemy

Distance calculation uses SuperWoW's precise coordinates when available, otherwise falls back to interact distance estimation.

## Class Configuration

Each tank class has its own taunt and snap spell options:

| Class   | Taunt Spell       | Snap Spells |
|---------|-------------------|-------------|
| Shaman  | Earthshaker Slam  | Earth Shock, Stormstrike, Lightning Bolt, Chain Lightning, Stoneclaw Totem, Lightning Strike |
| Druid   | Growl             | Maul, Swipe, Savage Bite |
| Paladin | Hand of Reckoning | Holy Strike, Crusader Strike, Judgement |
| Warrior | Taunt             | Revenge, Thunder Clap, Shield Slam, Concussion Blow, Sunder Armor, Heroic Strike |

## Technical Notes

- Works purely via unitID target chains (player, party, raid, pets)
- No combat log parsing
- No nameplate scanning  
- No threat APIs
- Every HUD entry is backed by a valid unitID that `UnitExists()` can resolve
- SuperWoW is only used for precise distance calculation (optional enhancement)
- Addon is dormant on non-tank classes (Mage, Rogue, Hunter, Priest, Warlock)

## Changelog

### v3.1.0
- Fixed spell dropdown to properly filter to only learned spells (all classes)
- Improved spellbook scanning reliability
- Updated documentation with attribution

### v3.0.1
- Renamed addon folder from ShamanTankAssist to TankAssist
- Changed SavedVariables from ShamanTankAssistDB to TankAssistDB
- Added automatic migration from old settings

### v3.0.0
- Rebranded from ShamanTankAssist to TankAssist
- Added support for Druid, Paladin, and Warrior tank classes
- New slash commands: `/ta` and `/tankassist`
- Spell dropdown now only shows spells your character knows
- Taunt spell is now class-configurable
- Removed all threat API and nameplate scanning code
- Improved robustness and nil safety throughout

### v2.6.0
- Fixed uncontrolled target detection
- Removed threat percentage display
- Fixed taunt-then-fallback to work in single keypress

### v2.5.0
- Added HUD line coloring (red enemy, green friendly)
- Added "Prefer furthest enemy" priority option
- Reorganized UI layout
- Added Chain Lightning, Stoneclaw Totem, Lightning Strike to spell list

---

**Built by Auter** | Additional refactoring performed by Claude
