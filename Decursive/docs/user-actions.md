Decursive, user possible actions
--------------------------------

*How to use Decursive at the maximum of its possibilities*

- **Remove afflictions:**

    - Using the [MUFs][]:

	    If you've displayed the Micro-Unit-Frame (on by default) you can [click on
	    the micro-frames][curseexemple1] to *cure, target or focus*.

    - Using the [mouse-over macro][]:

	    A special macro created and maintained by Decursive automatically.
	    (see the link above for more details)

- **Choose who your want to cure** and their priority:

    You can easily **organize the micro-unit frame order** by using the [**priority** and
    **skip** list][prioskipopts], clicking on the buttons in the [Decursive bar][decursivebar] (These list can *also*
    be displayed by *Ctrl-Left-Clicking* and *Shift-Left-Clicking* on the [MUF][] [handle][mufshandle] or on Decursive **Mini-Map Icon**).

    These lists allow you to **dynamically sort** the members of your raid or
    group per **class**, **raid group** or **per name**. A typical
    priority list looks like [this][prioskipopts]:

	1. *Your name* (ex: Archarodim) *(You're always the first player displayed)*
	2. *The tank name*
	3. [Priests]
	4. [Paladin]

	    Etc...

    The lists Interface allows you to **add, move, delete** entries very easily and intuitively.

    That's why **Decursive doesn't need to display the player names on the MUF interface**:
    The more the player is high in the window the more important it is to cure him as quickly as possible.

    **You just need to click on the MUF. No time or thoughts are wasted
    reading a player name and choosing if you have to cure him or not.**

- **Set Decursive's interface to feet your needs:**

    - **[The main 'Decursive bar'][decursivebar] and the live-list:**

	    This bar is the anchor of the live-list, it can also be used to access
	    Decursive options and different frames.

	    *Middle-Clicking* or *Ctrl-Left-Clicking* on the label "Decursive" will hide
	    the buttons and lock the frame and the live-list position.
	    *Alt-Click* to move the bar and the live-list.

	    Once you've placed the bar at a position you like you can **hide it**
	    completely clicking on the **'X'** button.

	    Various options exists to [customize how the live-list behaves][livelistopts].

    - **The** [MUFs][] **window**:

	    You can change almost [*every aspects* of this window **(Size, Shape,
	    Colors, Behavior, opacity, spacing, etc...)**][mufsdisplayopts], just look in the options.

	    **Move the MUF window** by *Alt-Left-clicking* above the first MUF, there is a
	    hidden [**handle**][mufshandle] to move the frame.

- **WoW key binding interface:**

	You can bind a lot of things to keys under "Decursive" section.

- **The option menu:**

    There are **several ways** to access the options:

     - On the MUFs handle, or on Decursive icon (Mini-Map or LDB), *Alt-Right-Click*
       to display a [**static option panel**][generalopts]. (Or type /Decursive in the chat window)
     - In Blizzard Interface->Addons panel, there is a Decursive section.

    Each option has an explanation tool-tip, here are **the most important ones**:

    - **Bind Decursive [mouse-over macro][] to a key:**

	    Hitting the bound key will cure the unit under your mouse pointer (the
	    key alone is the first spell, use *Ctrl+key* for the 2nd spell and *shift* for
	    the third)

    - You can [**choose what you want to cure** and the **priority**
      of **each affliction type**][cureopts], the priority determines what affliction is shown
      first (in the live-list) but also the key and click mapping of your spells in
      the MUFs and in the [mouse-over macro][] (look at the tool-tips to know the
      current bindings)

    - You can [**add afflictions** to ignore][filteropts] while in combat (or always) per
      **class**, it **avoids to waste time and mana** ; Decursive already has
      a comprehensive affliction list ignored on specific classes.

	    The addition of affliction names is **easily done** through a dynamic menu in the
      options listing recently cured ones *(no need to manually enter the affliction
      name)*

    - You can **display a fake affliction** to set and place the different aspects
      of Decursive's interface when a real affliction is detected.

    - Change the way and where Decursive displays its [various messages][messagesopts].

    - You can **save your settings** per character/server/class
      and create custom [option profiles][generalopts].


*See also:*

- [Micro Unit Frames documentation][MUFs]
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
[generalopts]: ../README.md#settings-guide
[livelistopts]: ../README.md#micro-unit-frames-mufs
[mufshandle]: MUFs.md
[decursivebar]: ../README.md#slash-commands
[messagesopts]: ../README.md#alerts-and-sounds
