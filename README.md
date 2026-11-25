# URBAN RPG — Godot 4 (V0.4)

Gameplay-first third-person RPG prototype. The project stays native Godot 4; it is a playable game project, not an editor or a web/Three.js conversion.

## Requirements
- Godot 4.2 or newer
- Forward+ renderer

## Run
Open `project.godot` in Godot and press F6/F5. The main scene is `scenes/game.tscn` and starts directly in the urban gameplay area.

## Controls
### Keyboard and mouse
- `W A S D` — camera-relative movement
- `Shift` — run
- `Space` — jump
- Mouse — orbit camera
- Mouse wheel — camera zoom
- `E` — interact with a nearby NPC, pickup or door
- `I` — open/close inventory
- `Escape` — pause / resume

### Gamepad
- Left stick — movement
- Right stick — camera
- A / Cross — jump
- Left-stick press — run

### Touchscreen
- Left virtual joystick — movement
- Right virtual joystick — camera
- JUMP — jump
- RUN — hold to run
- USE — interact
- PAUSE — pause menu

## V0.4 playable slice
- One playable Mixamo humanoid with the included `idle`, `walking` and `running` source clips
- `CharacterBody3D` player root with a separate capsule collider
- Independent camera yaw and character facing
- Camera-relative analog movement, acceleration/deceleration, gravity and jump buffering/coyote time
- Third-person `SpringArm3D` camera with collision handling and mouse-wheel zoom
- Compact procedural city block with collision-enabled road, sidewalks, buildings and street furniture
- Interaction targeting: the nearest in-range interactable displays a contextual prompt
- First RPG mission: talk to a local resident, collect the parcel, enter the shop and deliver it at the counter; successful delivery adds $100 to the HUD cash balance
- Shop interior with entry/exit teleport interaction
- Gameplay HUD with speed, cash balance, contextual interaction prompt and mission objective
- Touch controls and pause/restart/quit menu
- Centered dialogue modal with next/close behavior and a procedural NPC idle/talk motion layer
- Hinged shop doors with visible animation and matching collision before the room transition
- Inventory panel (`I`) with parcel tracking
- ConfigFile save/load for player position, camera yaw, money, quest state and inventory; manual, periodic and close-request saving
- Pause menu save/load actions

## Project structure
- `scenes/game.tscn` — gameplay entry scene
- `scenes/player.tscn` — playable character, collider, visual rig and camera
- `scripts/player.gd` — player movement, camera and locomotion animation
- `scripts/virtual_joystick.gd` — reusable touchscreen joystick
- `scripts/npc_actor.gd` — procedural resident idle/talk motion
- `scripts/door_controller.gd` — animated hinged door and collision
- `scripts/world.gd` — procedural city block, dialogue, inventory, interaction framework, first mission, HUD and persistence
- `scripts/pause_menu.gd` — pause, save/load, restart and quit
- `assets/models/mixamo_base.glb` — supplied Mixamo source asset
- `docs/GAMEPLAY_ARCHITECTURE.md` — gameplay architecture
- `docs/QA_TEST_PLAN.md` — manual test checklist

## Known prototype limits
- NPC animation is procedural blockout motion, not a skeletal animation clip.
- Door transitions still use a short location transfer after the physical door animation; this remains a prototype interior transition.
- The source animation set has `idle`, `walking`, `running`, `get_up`, `kick` and `knock_down`; it does not contain a dedicated jump/fall/landing cycle. The character uses the idle pose while airborne instead of playing an unrelated animation.
- The resident is a procedural blockout NPC with idle/talking motion, not yet a rigged citizen animation asset.
- The interior is a small test shop room. The city is a procedural blockout, not a finished open world.
- Vehicles, combat, branching quests, rigged citizen animation and persistent NPC schedules remain future milestones.

## Validation
A GitHub Actions workflow (`.github/workflows/godot-validation.yml`) imports/parses the project and starts the gameplay scene headlessly. A runtime verification has not yet been recorded in this development environment because the Godot executable is not installed here.

See `CHANGELOG.md`, `docs/GAMEPLAY_ARCHITECTURE.md` and `docs/QA_TEST_PLAN.md`.
