# STRATA//NULL v0.5 — physically authored depth traversal

The rejected v0.4 implementation placed arbitrary platform cutouts based on image bounds and temporarily disabled player collision on a synthetic bridge strip. **v0.5 replaces that specific implementation.**

Authoritative source only: `MEGASTRUCTURE_2P5D_ALL_7_ASSET_PACKS_MASTER_AUDITED_v1_1.zip`.

- Authored local contact strips for platform_bridges_003, _004, _008, _010, and ramps_stairs_depth_004; no original PNG modified. The source audit JSON and Godot scripts are bundled with the v0.5 Windows demo.
- Platform sockets now overlap in world coordinates rather than treating adjacency in a screenshot as walkable.
- A dedicated solid ramp collision layer supports actual Godot CharacterBody2D move_and_slide() during transitions. Collision is never disabled to interpolate through air.
- Deep and near loops branch off a continuous central walkway, with eight explicit reversible physical ramps.
- Source-side tests on alternate seed 4201339: 16/16 ramp directions passed; walking, jump and hit tests passed.
- Exported Windows EXE embedded game pack on default seed 4201337: all 16 ramp directions passed; movement and hit tests passed; 6 scenic captures plus 4 depth-midpoint captures were generated and inspected.
- Windows format is PE32+ x86-64 and exported via Godot 4.7.2. Native Windows GUI/GPU validation still outstanding.

**Not complete:** Only the five documented traversal sprite variants have scene-authored gameplay collision. The other PNGs remain indexed but most lack physical behavior and verified join sockets. Full free-Z locomotion, every pack's authored animation/FX/enemy behavior, dynamic construction, cinematic depth and a complete procedural region grammar remain future work. Do not call this a finished game or assert that all 6,480 PNGs are gameplay integrated. Keep `main` untouched.
