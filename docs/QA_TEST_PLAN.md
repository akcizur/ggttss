# QA Test Plan — V0.5

## Startup and player
- [ ] Project opens in Godot 4.2+ and starts `scenes/game.tscn`.
- [ ] Player capsule collides with road, sidewalks and buildings.
- [ ] WASD/left stick movement is camera-relative; right stick/mouse rotates only the camera.
- [ ] Shift/left-stick press runs; Space/A jumps.
- [ ] The player camera does not pull into the character capsule.

## NPC rigs and dialogue
- [ ] Resident appears on the street and shopkeeper appears inside the shop.
- [ ] Each NPC instance loads the Mixamo GLB and plays the real skeletal idle clip.
- [ ] Approaching an NPC shows the role-specific E prompt.
- [ ] E opens the correct resident/shopkeeper dialogue and pauses player movement.
- [ ] E/Jump or NEXT advances dialogue; Close/Escape closes it.
- [ ] NPC talk count and mood return to neutral when dialogue closes.

## Multi-step delivery quest
- [ ] Resident dialogue completion advances quest stage 0 to 1.
- [ ] Parcel pickup advances stage 1 to 2 and adds the parcel to inventory.
- [ ] Talking to the shopkeeper while carrying the parcel advances stage 2 to 3 and adds the receipt.
- [ ] Counter handoff advances stage 3 to 4 and consumes the parcel.
- [ ] Parcel does not respawn during the return-to-resident stage or after load.
- [ ] Returning to the resident and completing dialogue advances stage 4 to 5, consumes the receipt and awards $150.

## Doors and inventory
- [ ] Shop door panel and collider swing open before the room transition.
- [ ] Interior exit door swings open before returning to the street.
- [ ] I opens/closes the inventory and blocks character movement while open.
- [ ] Inventory shows cash, parcel, receipt and shop-key counts with item markers.

## Persistence
- [ ] Pause menu Save Game creates `user://urban_rpg_save.cfg`.
- [ ] Load Game restores money, quest stage, inventory, player transform/camera yaw and NPC positions/yaw/talk count/mood.
- [ ] Automatic save runs after dialogue closes, every 30 seconds and on window close.

## Known validation gap
- [ ] Headless CI validates import and scene startup, but it cannot verify rendered character appearance, camera feel, touchscreen behavior or actual player interaction. Those need a local interactive Godot run.
