# Changelog

## V0.4 — Dialogue, doors, inventory and persistence
- Added a centered dialogue modal with keyboard and button progression; player movement pauses while speaking.
- Added procedural NPC idle/talking animation for the resident blockout.
- Added hinged shop doors using an AnimatableBody3D leaf and collision, animated before the existing room transition.
- Added an inventory panel (`I`) with parcel and shop-key slots; the delivery parcel is added on pickup and removed on delivery.
- Added ConfigFile save/load for player transform, camera yaw, money, quest state and inventory; periodic and close-request autosave.
- Added save/load actions to the pause menu.
- Kept the original Godot 4 project, Mixamo player asset, city block and first delivery quest.

## V0.3 — First RPG interaction loop
- Added nearest-target interactions, resident dialogue, parcel pickup and delivery mission.
- Added compact shop interior and mission/cash HUD.

## V0.2 — Third-person gameplay foundation
- Added independent camera yaw and visual-character facing, camera-relative movement, jump buffering/coyote time, SpringArm collision and touch controls.
