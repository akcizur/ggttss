# Changelog

## V0.5 — Rigged NPCs and multi-stage RPG quest
- Replaced the blockout citizen visuals with independent instances of the original Mixamo GLB; NPCs play the embedded skeletal idle animation.
- Added a second NPC, the shopkeeper, inside the store.
- Expanded the delivery task into four player objectives: accept the job, collect the parcel, obtain the shop receipt, and return to the resident.
- Added receipt item tracking and emoji item markers in the inventory.
- Persisted NPC position, rotation, talk count and mood alongside player transform, quest stage, cash and inventory.
- Fixed NPC interaction routing so resident and shopkeeper dialogue is selected by NPC identity at every quest stage.
- Fixed pickup visibility after loading a save: a parcel remains collected after the counter handoff and is not respawned during the return stage.

## V0.4 — Dialogue, doors, inventory and persistence
- Added a centered dialogue modal with keyboard and button progression; player movement pauses while speaking.
- Added hinged shop doors using an AnimatableBody3D leaf and collision, animated before the existing room transition.
- Added an inventory panel (I) with parcel tracking.
- Added ConfigFile save/load for player position, camera yaw, money, quest state and inventory; periodic and close-request saving.
- Added save/load actions to the pause menu.

## V0.3 — First RPG interaction loop
- Added nearest-target interactions, resident dialogue, parcel pickup and delivery mission.
- Added compact shop interior and mission/cash HUD.

## V0.2 — Third-person gameplay foundation
- Added independent camera yaw and visual-character facing, camera-relative movement, jump buffering/coyote time, SpringArm collision and touch controls.
