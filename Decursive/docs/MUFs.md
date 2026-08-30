The Micro-Unit Frames (MUFs)
============================

Decursive makes your life easier, it [clearly shows you who is afflicted][curseexemple1] by
something you can remove, this is done using **Micro-unit-frames (MUFs)**.

A micro-unit-frame is a little square on your screen that *changes its appearance
according to the unit status*.  If you click on a MUF, it casts a cleaning
spell, **the choice of the spell depends of the mouse button you click**, Decursive
manages the button mapping automatically.

 MUFs have several colors ([which can be configured][mufscolors]):

 - **Full red**: the unit is in range and is afflicted by something you can cure by
   left-clicking on the MUF.

 - **Transparent red**: the unit is out of range and afflicted by something you could
   cure by left-clicking on the MUF

 - **Full blue**: idem as red but with right-clicking instead of left-clicking.

 - **Full orange**: idem as blue or red but with ctrl-left-clicking.

 - **Transparent grey**: The unit does not exists anymore.

 - **Dark Transparent green**: the unit is in scan range and is not afflicted by
   something you can cure.

 - **Transparent purple**: The unit is too far to be scanned or cured.

 - **Transparent light-green**: The unit is cloaked.

 - **Any color with a little green square in the middle**: the unit is
   Mind-Controlled (Charmed).

 - **Black**: the unit has been blacklisted because it was *out of line of sight* when you
   tried to cure it, the time in blacklist can be change in the options.

 - **Black with a white skull**: the player is dead. If Emergency Soul Link is
   the active resurrection fallback and ready, the square becomes **green** in
   range or **yellow** out of range. The item must be in carried bags, and the
   item itself or a simple `/use item:269586` macro must occupy any real action
   bar slot for passive range colors. Hidden and unselected bar pages work.

*The information above are also indicated by tool-tips in the game when you hover the MUFs.*

*MUFs display is done according to your settings*, **you can change every aspects
of the MUFs** (size, spacing, number, colors, grow directions, etc...), look in the [*Micro unit
frame* configuration options][mufsdisplayopts].

MUFs are very discreet when no action is required, you can see right through
them.

*You can change the spell mapping when you are not in combat*, **the mapping is
done according to your [cure priorities][cureopts]** ; go to the "[curing options][cureopts]", the
priorities are indicated by green numbers in front of the affliction types.

Besides casting, MUFs allow you to *target* the units by *Middle-clicking*,
*Ctrl-Middle-Clicking* will focus them. (To clear the focused unit, use the
command /clearfocus)
Mouse button mapping can be [completely customized][mufsmousebuttons].

**MUFs follow Group / roster order by default**, matching Blizzard's party or
raid roster. The MUF order setting can instead use Decursive's traditional
priority-list/current-group sequence, or mirror the visible DandersFrames order
when that optional addon is installed. Pets and a friendly focus remain
supported after the matched group members.

The [priority and skip list][prioskipopts] still controls cure priority and
exclusions. Choose **Decursive priority** as the MUF order when you want that
same priority list reflected in the visible frame sequence. (See
[Decursive usage][user-actions] for more information.)

**IMPORTANT:**

TO MOVE THE MUFS, ALT-CLICK AND HOLD THE HANDLE JUST ABOVE THE FIRST MUF (IT
HAS THE SAME SIZE AS A MUF AND HIGHLIGHTS WHEN YOUR MOUSE POINTER IS OVER IT).

*This handle has several uses, a tool-tip explains them all.*

*See also:*

- [Decursive usage][user-actions]
- [Decursive Macro documentation][mouse-over macro]
- [Frequently Asked Questions][FAQ] *try this before asking any question*
- [commands][]




[MUFs]: MUFs.md "Micro Unit Frames"
[MUF]: MUFs.md "Micro Unit Frame"
[FAQ]: faq.md "Frequently Asked Questions"
[mouse-over macro]: macro.md "Decursive's mouse-over macro documentation"
[commands]: commands.md "Command lines"
[user-actions]: user-actions.md "Decursive user actions"

[cureopts]: ../README.md#cure-priorities-and-mouse-bindings
[filteropts]: ../README.md#priority-and-skip-lists
[prioskipopts]: ../README.md#priority-and-skip-lists
[curseexemple1]: ../README.md#micro-unit-frames-mufs
[mufsdisplayopts]: ../README.md#micro-unit-frames-mufs
[mufscolors]: ../README.md#micro-unit-frames-mufs
[mufsmousebuttons]: ../README.md#cure-priorities-and-mouse-bindings
