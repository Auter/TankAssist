# TankAssist
A lightweight tanking addOn for Vanilla 1.12, that helps you quickly identify enemies that are not currently focused on you and provides a configurable “snap attention” key.

Supported classes:

🛡️ Warrior

🪓 Shaman

🐻 Druid

✝️ Paladin

**⭐ What TankAssist Does**

Displays a small HUD of:

enemies currently attacking your party/raid members that are not targeting you

<img width="251" height="65" alt="hudtankassist" src="https://github.com/user-attachments/assets/48fdce54-c61b-4f41-9161-9493b4adab9e" />

provides a configurable macro that will - 

optionally attempt taunt first

if fail, then cast your chosen spell

option to only target, cast or target+cast (your choice)

Lets you blacklist tanks / players you don’t want to pull from

Optionally avoids CC’d targets (Polymorph, Sap, etc.)

Optional skull-marking for snap targets

Respects your current target if you prefer “cast only”

Works with or without SuperWoW installed

**🧠 How it Works (Realistically)**

TankAssist relies on real unitIDs.
It discovers enemies through:

your current target chain

party / raid member target chains

pet targets

*target, targettarget, partyXtarget, raidXtarget, pettarget, etc.*

This is how the 1.12 API actually works.

If nobody has targeted an enemy at all, it does not exist to the client — no addon can see it.

Therefore:

✔️ If a mob is attacking the group and someone is targeting it, TankAssist sees it

✔️ If that mob is attacking someone other than you, it appears in the HUD

✔️ Snap key can grab it instantly

**❌ If nobody has ever targeted the mob, addons cannot discover it**

**⚠️ Limitations**

This is not an aimbot and does not violate input rules.

Limitations include:

cannot detect mobs never targeted by anyone

cannot always know exact threat levels

relies on tank awareness, keypresses, tank positioning, resource awareness

snap key respects line-of-sight and spell range

cannot taunt things immune to taunt (by design)

This addon is designed to assist, not automate.

**Open configuration:**

/ta
/sta
/tankassist

<img width="343" height="555" alt="tankassist" src="https://github.com/user-attachments/assets/191d856e-28b3-4340-9f71-705ae055d580" />

Bind key in:

Key Bindings → TankAssist → Snap Attention

Macro: /run TA_Snap()  

**🧩 Current Feature Status**

This project is:

✔️ functional

✔️ raid-tested

✔️ works well in practice

⚠️ still a work in progress

🛠️ likely to receive UI polish and refinements

💬 open to feedback and ideas

Please expect:

occasional rough edges

edge-case targeting quirks

Bug reports are welcome.

**Installation:**

1. Extract the zip file.
2. Ensure the resulting folder is named `TankAssist` and rename if needed.
3. Move that folder to `[Path]\Interface\Addons`.

**🤝 Credits**

Created by Auter

Additional refactoring and iteration assisted via LLM-based tooling.
