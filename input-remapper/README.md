# Orbweaver MMO profile

For the Razer Orbweaver Chroma (`1532:0207`), using the factory inputs confirmed
on this machine. Input Remapper applies this only to the selected Orbweaver
device group. Unlisted keys pass through, including Alt, Space, and Tab.

Install a copy and optionally apply it:

```bash
python3 setup/orbweaver-mmo.py --dry-run --apply
python3 setup/orbweaver-mmo.py --apply
```

This creates `~/.config/input-remapper-2/presets/Razer Razer Orbweaver Chroma/Orbweaver MMO.json`.
It preserves other presets and autoload preferences. Reinstalling backs up a
changed copy before replacement. GUI changes remain local; copy the edited
preset back to `input-remapper/orbweaver-mmo.json` explicitly to keep them here.
The ordinary bootstrap installs Input Remapper but does not overwrite presets.

## Physical layout and emitted keys

| Buttons | Outputs, left to right |
| --- | --- |
| 01–05 | Escape, 1, 2, 3, 4 |
| 06–10 | Tab, Q, F5, E, R |
| 11–15 | Left Shift, F6, F7, F8, F |
| 16–20 | Left Ctrl, Z, X, C, V |
| Upper thumb | Left Alt |
| Lower thumb | Space |
| Direction pad up/down/left/right | W / S / A / D |

Physical W/A/S/D become F5/F6/F7/F8 so the main grid is independent of thumb
movement. The direction mappings assume the pad emits Up/Down/Left/Right arrow
events. Diagonals should combine two directions; verify on the actual device.
Outputs use Linux key codes, preserving held keys and avoiding layout-dependent
character lookup. There are no timed macros or repeated action sequences.

## In-game assignments

Bind W/S to forward/backward and A/D to strafe left/right. Use the mouse to turn.
Bind action bars to these 16 keys, then Shift+key and optionally Ctrl+key:

```text
1   2   3   4       less frequent abilities / utility
Q   F5  E   R       interrupt / short cooldown / control / offensive cooldown
F6  F7  F8  F       four core combat abilities
Z   X   C   V       defensive / escape / heal / movement ability
```

Assign Escape to the menu, Tab to targeting, and Space to jump. Reserve Alt for
targeting or self-casting if desired. Remove conflicting in-game bindings for
the action keys and their modifier combinations.

## Testing and recovery

After applying, test all keys, held movement, diagonals, Shift/Ctrl with movement,
and movement while jumping. Enable **Autoload** in the GUI only after testing.
This profile applies outside games too while active; use **Stop** on the
Orbweaver in Input Remapper when finished to restore native inputs.

To stop from a terminal:

```bash
pkexec input-remapper-control --command stop --device 'Razer Razer Orbweaver Chroma'
```

Do not enable the profile for your regular keyboard. Hardware factory settings
and in-game action bindings are not changed by installing this preset.
