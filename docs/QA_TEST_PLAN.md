# QA Test Plan — V0.4

## Startup and player
- [ ] Project opens in Godot 4.2+ and starts `scenes/game.tscn`.
- [ ] Player capsule collides with road, sidewalks and buildings.
- [ ] WASD/left stick movement is camera-relative; right stick/mouse rotates only the camera.
- [ ] Shift/left-stick press runs; Space/A jumps.

## NPC and dialogue
- [ ] Approach the resident; contextual E prompt appears.
- [ ] E opens the dialogue modal and pauses player movement.
- [ ] E/Jump or NEXT advances dialogue; Close/Escape closes it.
- [ ] Completing the opening conversation starts the delivery mission.
- [ ] Resident switches to the talking motion while dialogue is open.

## Doors and delivery
- [ ] Shop door panel and collider swing open before the room transition.
- [ ] Interior exit door swings open before returning to the street.
- [ ] Parcel pickup adds one parcel to inventory and hides the world pickup.
- [ ] Delivery consumes the parcel, completes the quest and adds $100.

## Inventory and persistence
- [ ] I opens/closes the inventory and blocks character movement while open.
- [ ] Inventory shows cash, parcel and shop key counts.
- [ ] Pause menu Save Game creates `user://urban_rpg_save.cfg`.
- [ ] Load Game restores money, quest state, inventory, player position and camera yaw.
- [ ] Automatic save runs after progress changes, every 30 seconds and on window close.

## Known validation gap
- [ ] Run the headless CI workflow with Godot 4.2.2; this environment does not include a Godot executable, so engine runtime validation must be completed by GitHub Actions or a local Godot install.
