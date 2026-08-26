# Zhaohu's Decursive v12.0.7

This release incorporates the manual delimiter repair that restored the addon.

- Removed every remaining WowAce `@debug@` preprocessing marker from the embedded LibQTip library.
- Debug-only sections are now ordinary inert Lua long comments that packaging tools cannot rewrite.
- The invalid `]==]]==]` sequence is rejected during release validation.
- No MUF behavior, profile settings, dispel detection, protected-aura handling, sound behavior, or secure click bindings were changed.
