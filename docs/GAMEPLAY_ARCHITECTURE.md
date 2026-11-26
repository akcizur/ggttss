# Gameplay Architecture — V0.5

## Runtime ownership
- `game.tscn` starts the gameplay world directly.
- `player.tscn` owns the CharacterBody3D capsule, visual Mixamo rig, camera mount and SpringArm.
- `player.gd` owns player movement, camera input and locomotion animation.
- `world.gd` owns the procedural city, interaction targeting, dialogue/inventory UI, quest progression, doors, HUD and persistence.
- `npc_actor.gd` owns each NPC's independent Mixamo AnimationPlayer, idle loop and talk-state gesture.
- `door_controller.gd` animates a hinged AnimatableBody3D leaf with its collision shape.

## NPCs
- `resident` is the quest giver on the street.
- `shopkeeper` is spawned inside the shop.
- Both are separate instances of `assets/models/mixamo_base.glb`, each with its own AnimationPlayer and NPC root.
- The imported source pack contains skeletal idle/walk/run and action clips; NPCs currently use the real idle clip. Talk has no source clip, so a subtle procedural motion layer is used during dialogue.
- Per-NPC state persisted: world position, yaw, dialogue/talk count and mood.

## Delivery quest state machine
- `0 / NOT_STARTED`: resident offers the job.
- `1 / FIND_PARCEL`: collect the parcel outside the shop.
- `2 / TALK_TO_CLERK`: show the parcel to the shopkeeper and receive a receipt.
- `3 / DELIVER_PARCEL`: hand the parcel over at the counter.
- `4 / RETURN_TO_RESIDENT`: take the receipt back to the resident.
- `5 / COMPLETED`: resident acknowledges delivery and pays $150.
- Inventory stores `parcel` and `shop_receipt` counts.

## Interaction flow
- Nearby interaction zones are Area3D instances with an `interaction_type`, prompt and optional destination.
- `E` and touchscreen USE call the same `request_interaction()` entry point.
- NPC interaction opens a modal dialogue; finishing the first conversation accepts the delivery task.
- Door interactions swing the hinged door, then move the player to the linked blockout interior/exterior location.
- Pickup adds `parcel` to inventory; the shopkeeper issues `shop_receipt`; counter delivery consumes the parcel; returning to the resident consumes the receipt and awards $150.

## Persistence
- Save file: `user://urban_rpg_save.cfg` via ConfigFile.
- Saved values: player position/yaw/camera yaw, money, quest stage and flags, inventory dictionary, and each NPC's position/yaw/talk count/mood.
- Save is available from the pause menu, runs automatically every 30 seconds, and runs on a window close request.

## Prototype limits
- NPCs share the supplied Mixamo base appearance. Bespoke citizen outfits and facial/lip-sync animation are not present yet.
- Talk gestures are procedural; the GLB has no dedicated talk clip.
- The city and shop are blockout geometry. Vehicles, combat, quest branching and citizen schedules are not implemented.
