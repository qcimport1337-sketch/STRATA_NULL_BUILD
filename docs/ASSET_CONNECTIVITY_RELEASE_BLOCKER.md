# STRATA//NULL — master-pack assembly release blocker

**Status: v0.4 rejected. Do not treat prior structural runtime tests as asset integration proof.**

Source of truth: `MEGASTRUCTURE_2P5D_ALL_7_ASSET_PACKS_MASTER_AUDITED_v1_1.zip` ONLY.

## Verified audit findings

- ZIP: 6,614 total entries, 6,480 PNG entries. All original pack paths preserved.
- Traversal manifest: 349 records; all have `gameplay_eligible:false`, `walkable_surface:null`, `collision_shape:null`. 245 records have estimated visual endpoint hints, none certified physical.
- Category counts: 55 platform bridges, 42 ramps/stairs/depth, 51 connectors/ledges, 35 junctions, 26 ladders/lifts, 36 corridors/doors, 48 occluders, 56 reference mixed.
- Main architecture manifest: 1,586 sprites visually eligible for procedural placement, but connectors flagged unverified; gameplay collision not pixel-calibrated.
- Seven-pack traversal integration requires **scene-authored physics surfaces, endpoint graph, depth lanes, capsule clearance, and traversal ability**. Art pixels, image bounds and visual proximity are not navigation authority.

## Root cause in rejected v0.4 local candidate source

- `traversal_builder.gd`: randomly chooses 20 unverified platform images by ID, scales widths and uses hand-coded `DECK_PX` rather than reviewed contact geometry.
- Depth connectors are `Polygon2D` strips textured with an atlas crop from `platform_bridges_003`; not physically authored ramps or registered depth surfaces.
- `player.gd`: `collision_mask=0` during a 0.75 second linear 2D connector movement. A lane-mask swap at arrival is not grounded depth locomotion.
- `routes_connected()` merely flood-fills 3 abstract lane IDs, not real physical edge endpoints and collision clearance.
- Mixed perspective/isometric ramp/junction cutouts cannot all be composited as identical side-on walk surfaces without calibration.

## Required gate before any next playable EXE

1. Preserve the unmodified master pack; create a separate reviewed world-space placement catalog.
2. Author each actual gameplay prefab's legal entry/exit sockets, XY+depth/Z transform, contact strip, physical collider, material and allowable scale/orientation.
3. Compose coherent structures from **compatible sockets**; reject unverified joins automatically. Visual/decorative sprites do not generate collision.
4. For depth traversal, implement continuous physical world support and correct perspective/occlusion; never disable collision to interpolate across a disconnected sprite.
5. Test real actor feet/contact and endpoint paths bidirectionally on multiple seeds; inspect screenshots as a player in mid-transition and at destinations.
6. Export only after those tests and the Windows embedded-pack audit pass. Keep `main` untouched.

This is an audit of v0.4 and a release blocker, not an assertion that the replacement system has already been built.
