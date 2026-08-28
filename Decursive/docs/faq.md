# Frequently Asked Questions

## How do I dispel someone?

Click an afflicted [Micro Unit Frame](MUFs.md) with the mouse button assigned to
the cure priority you want. The bindings are configured under **Cure** or
**All Settings > Spells & Bindings**.

## How do I move the Micro Unit Frames?

Unlock MUF movement under **MUFs**, then drag the MUF handle. Use `/dcrreset` if
the frames are off-screen.

## Why can Decursive not cure everyone with one button?

World of Warcraft requires a hardware action for each secure spell cast and
does not let addons choose arbitrary protected targets during combat. Decursive
therefore presents secure unit buttons; the player chooses the unit and binding
for every cast.

## Why did a setting wait until combat ended?

WoW protects secure frames, bindings, native aura registrations, and some layout
changes during combat. Decursive queues supported changes and applies them when
the restriction ends.

## Why are the MUFs missing?

1. Confirm both `Decursive` and `Decursive_Options` are installed and enabled.
2. Open `/dcr` and confirm **MUFs > Show MUFs** is enabled.
3. Run `/zdmuf` before `/reload` so the original cold-start state is retained.
4. Include the resulting information in a bug report if the frames do not recover.

## Why does Test Sound work while a live aura is silent?

Live protected-aura sounds require a public Spell ID registered before combat.
Run `/zdsound`, note the encounter and Spell ID when available, and include
that information in a report. Stack increases and refreshes of one continuing
aura are intentionally silent.

## How do I report a problem?

Run `/dcrdiag`, then open the complete copyable report with `/dcrreport`.
Include the WoW build, addon version, class and specialization, activity type,
steps to reproduce, and any BugSack or BugGrabber stack trace in a
[GitHub issue](https://github.com/randylorfing/Decursive/issues).

See also the [user guide](../README.md), [commands](commands.md),
[MUF guide](MUFs.md), [macro guide](macro.md), and
[user actions](user-actions.md).
