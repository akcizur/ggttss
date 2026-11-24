# URBAN RPG — Godot 4

Gameplay-first third-person RPG prototype based on the supplied Godot 4 controller boilerplate and its original Mixamo humanoid/animation assets.

## Run
Open `project.godot` in Godot 4.2+ and run the project. The main scene is `scenes/game.tscn`; it starts directly in the playable urban block.

## Controls
- `W A S D` — camera-relative movement
- `Shift` — run
- `Space` — jump
- Mouse — third-person camera
- `E` — interact with the marked shop entrance
- `Escape` — pause / resume
- Gamepad left stick — movement
- Gamepad right stick — camera
- Gamepad A / Cross — jump
- Gamepad left-stick press — run

## Current playable slice
- One playable Mixamo humanoid using the original embedded `idle`, `walking`, and `running` animations
- Separate `CharacterBody3D` root and invisible capsule collider
- Third-person orbit camera with a collision-aware `SpringArm3D`
- Acceleration/deceleration, gravity, jump, camera-relative movement and smooth visual facing
- Small procedural urban street block with buildings, windows, sidewalks, lamps, trees and street furniture
- Gameplay HUD and pause/restart/quit menu

## Project direction
This is a Godot gameplay project, not an editor. Future milestones: interaction system, NPCs, vehicles, inventory, quests, save/load and expansion of the city block.

The city block is currently a prototype environment built from simple collision-enabled primitives. The supplied Mixamo rig and source animations are retained.
