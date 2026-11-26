# URBAN RPG — Godot 4 (V0.5)

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

## V0.5 playable slice
- One playable Mixamo humanoid with the included `idle`, `walking` and `running` source clips
- Separate `CharacterBody3D` root and invisible capsule collider
- Independent camera yaw and character facing
- Camera-relative analog movement, acceleration/deceleration, gravity and jump buffering/coyote time
- Third-person `SpringArm3D` camera with collision handling and mouse-wheel zoom
- Compact procedural city street block with collision-enabled road, sidewalks, buildings and street furniture
- Resident NPC and shopkeeper NPC are separate instances of the supplied rigged Mixamo GLB; both play its real skeletal `idle` clip
- NPC talk state has a subtle procedural gesture layer; the included model asset has no dedicated talk animation clip
- Four-step delivery quest: accept the job, collect the parcel, show it to the shopkeeper and receive a receipt, hand the parcel over at the counter, then return the receipt to the resident for $150
- Centered dialogue modal with next/close behavior; player movement pauses during dialogue
- Hinged shop doors with visible animation and collision, followed by the prototype room transition
- Inventory panel (`I`) with emoji item markers, parcel and shop receipt counts
- ConfigFile save/load for player transform, camera yaw, money, quest stage, inventory and NPC position/rotation/talk count/mood
- Manual save, periodic autosave every 30 seconds and save on window close
- Pause menu save/load/restart/quit actions
- Touch controls and gameplay HUD

## Project structure
- `scenes/game.tscn` — gameplay entry scene
- `scenes/player.tscn` — playable character, collider, visual rig and camera
- `scripts/player.gd` — player movement, camera and locomotion animation
- `scripts/virtual_joystick.gd` — reusable touchscreen joystick
- `scripts/npc_actor.gd` — Mixamo NPC idle animation and talk-state layer
- `scripts/door_controller.gd` — animated hinged door and collision
- `scripts/world.gd` — procedural city, NPCs, dialogue, quest flow, inventory, HUD and persistence
- `scripts/pause_menu.gd` — pause, save/load, restart and quit
- `assets/models/mixamo_base.glb` — supplied Mixamo source rig and animations
- `docs/GAMEPLAY_ARCHITECTURE.md` — gameplay architecture
- `docs/QA_TEST_PLAN.md` — manual test checklist

## Known prototype limits
- NPCs share the same supplied Mixamo character appearance. They are separate rig instances but do not yet have bespoke citizen outfits or facial/lip-sync animation.
- NPC talking uses a subtle procedural gesture layered over the real skeletal idle clip.
- The shop door animates its leaf and collision, then uses a short location transfer for the prototype interior transition.
- The interior is a small test shop room. The city is a procedural blockout, not a finished open world.
- Vehicles, combat, branching quests, citizen schedules and a full quest journal remain future milestones.

## Validation
GitHub Actions (`.github/workflows/godot-validation.yml`) imports/parses the project and starts the gameplay scene headlessly after each push. Headless CI confirms the project can be imported and the scene starts; it does not replace interactive graphics/input testing.

See `CHANGELOG.md`, `docs/GAMEPLAY_ARCHITECTURE.md` and `docs/QA_TEST_PLAN.md`.
