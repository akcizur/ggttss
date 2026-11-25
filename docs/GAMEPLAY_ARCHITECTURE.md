# Gameplay Architecture — V0.4

## Runtime ownership
- `game.tscn` starts the gameplay world directly.
- `player.tscn` owns the CharacterBody3D capsule, visual Mixamo rig, camera mount and SpringArm.
- `player.gd` owns movement, camera input and player locomotion animation.
- `world.gd` owns city blockout, interaction targeting, dialogue/inventory UI, first mission, doors and persistence.
- `npc_actor.gd` gives the current procedural resident an idle/talking motion layer; it is intentionally independent from the player rig.
- `door_controller.gd` animates a hinged AnimatableBody3D leaf with its collision shape.

## Interaction flow
- Nearby interaction zones are Area3D instances with an `interaction_type`, prompt and optional destination.
- `E` and touchscreen USE call the same `request_interaction()` entry point.
- NPC interaction opens a modal dialogue; finishing the introductory conversation accepts the delivery task.
- Door interactions open the hinged door, then move the player to the linked blockout interior/exterior location.
- Pickup adds `parcel` to the inventory dictionary; delivery consumes it and adds $100.

## Persistence
- Save file: `user://urban_rpg_save.cfg` via ConfigFile.
- Saved values: player position, visual yaw, camera yaw, money, quest flags and inventory dictionary.
- Save is available from the pause menu, runs automatically every 30 seconds, and runs on a window close request.

## Prototype limitations
- The resident uses procedural blockout geometry with an idle/talk motion script; it is not yet a skeletal NPC animation asset.
- The current shop door animates its visible panel and collision, then uses the prototype room transition to enter/exit the shop.
- The city, shop and props remain blockout geometry. There are no vehicles, combat, branching quests or citizen schedules yet.
