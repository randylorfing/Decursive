# Zhaohu's Decursive v12.0.4

Vertical MUF spacing now behaves consistently with original Decursive.

- With **Tie horizontal and vertical spacing** enabled, the Horizontal slider controls both directions and the locked Vertical readout mirrors it immediately.
- With the tie disabled, Horizontal and Vertical spacing can be adjusted independently.
- The live MUF layout now treats Horizontal spacing as authoritative whenever the two values are tied, correcting older profiles with mismatched saved values.
- Linked slider readouts refresh without rebuilding the settings page while a slider is being dragged.

Vertical spacing changes the distance between MUF rows. A one-row layout will not visibly change until the MUFs wrap to a second row.
