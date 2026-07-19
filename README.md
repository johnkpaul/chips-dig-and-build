# Chip's Dig & Build

A 10-minute, 3-level touch platformer for an 8-year-old: dig dirt, place blocks, collect
crystals, and unlock a family "Mission File" at the end. Built for Godot 4.2+, mobile web
first. Every texture and sound is generated in code — there are no imported art or audio
files anywhere in this project.

## Opening in Godot

1. Install Godot 4.2 or later (the [Standard build](https://godotengine.org/download), not
   .NET/C# — this project is pure GDScript). Some features (the `TileMapLayer` node used by
   `world_generator.gd`) require **Godot 4.3+**; if you're on 4.2 exactly, replace the
   `TileMapLayer` usage with the legacy `TileMap` + `set_layer_*` API.
2. Open Godot, choose **Import**, and select the `project.godot` file in this folder.
3. On first open, Godot will import the project. Press **F5** (or the Play button) to run.
   `main.gd` automatically calls `ProceduralArt.run_all()` if `generated_assets/` is empty,
   so the very first run may take an extra second to generate all sprites before the title
   screen appears.

## Testing on desktop

Desktop testing uses your mouse as a stand-in for touch:

- `input_devices/pointing/emulate_touch_from_mouse` is enabled in `project.godot`, and
  `touch_controls.gd` also listens for `InputEventMouseButton`/`InputEventMouseMotion`
  directly, so the left mouse button drives the joystick (left half of the screen) and the
  contextual action buttons (right half) exactly like a finger would.
- There is **no keyboard control scheme** — this is intentional. The game is touch-native;
  keyboard input is not wired to anything.
- Run the project with F5 and click-drag on the left half of the window to move Chip, and
  click the circular buttons on the right to jump/drill/place blocks.

## Exporting for mobile web

1. In the Godot editor, open **Project > Export…**. The `export_presets.cfg` in this repo
   already defines a **Web** preset (HTML5, canvas resizes to fill the browser window,
   headless export). You'll need the Godot **Web export templates** installed (Editor >
   Manage Export Templates).
2. Either export from the editor UI, or run the automation script from a terminal:
   - macOS/Linux: `./build.sh`
   - Windows: `build.bat`
   Both scripts (a) regenerate `generated_assets/` via
   `godot --headless --script scripts/procedural_art.gd`, then (b) export the "Web" preset
   to `build/web/index.html`. Set `GODOT_BIN` if `godot` isn't on your `PATH`.
3. Serve `build/web/` over HTTP (opening `index.html` via `file://` will not work — browsers
   block the WASM/threading requirements). Locally: `cd build/web && python3 -m http.server`.

### Mobile audio note

Browsers block audio playback until the user interacts with the page. `main.gd` calls
`ProceduralAudio.unlock_audio()` on the very first tap/click on the title screen, which plays
a near-silent buffer to wake the browser's audio context before the background music starts.

## Customizing the Mission File message

The reveal at the end of Level 3 ("YOUR NEXT MISSION: ...") is controlled by
`GameManager.custom_mission_message` (set it before Level 3 finishes, e.g. from a debug
console or a future settings screen) or, more simply, by editing the **Custom Message**
export variable directly on the `MissionFile` node/scene (`scenes/mission_file.tscn` →
`mission_file.gd` → `@export var custom_message`). It defaults to
`"A TRIP TO THE CHOCOLATE MOUNTAINS"` — edit this string (in the Inspector or in the script
default) to reveal your own family news instead. Avoid trademarked names; "Chocolate
Mountains" is used deliberately as a generic, copyright-safe placeholder.

## Browser deployment notes

- **GitHub Pages**: push the contents of `build/web/` to a `gh-pages` branch (or the `/docs`
  folder on `main`) and enable Pages in the repo settings. GitHub Pages serves static files
  over HTTPS by default, which the WASM build needs.
- **Netlify / Vercel / any static host**: drag-and-drop or deploy the `build/web/` folder
  directly — no build step is required on the host side, since `build.sh`/`build.bat` already
  produced the final static bundle.
- Make sure your host serves `.wasm` files with the `application/wasm` MIME type (most modern
  static hosts, including GitHub Pages and Netlify, do this correctly out of the box).
- The game locks to landscape orientation (`display/window/handheld/orientation = "landscape"`)
  and requests fullscreen-friendly canvas resizing — test on an actual phone in landscape
  before sharing the link with your 8-year-old.

## Project layout

```
project.godot              Window/stretch/input config, autoloads
default_bus_layout.tres    Master/SFX/BGM audio buses
scenes/                    All .tscn scene files
scripts/
  game_manager.gd           Autoload: level index + block backpack state
  procedural_audio.gd        Autoload: generates & plays all SFX/BGM
  procedural_art.gd          Generates every PNG into generated_assets/
  level_data.gd               3 levels as ASCII tile grids
  world_generator.gd           Builds a level: tiles, crystals, gate, stations
  player.gd                    Chip: movement, jump, drill, place, reboot
  touch_controls.gd / touch_button.gd   Joystick + contextual action buttons
  camera_follow.gd              Smoothed, bounds-clamped camera
  ui_manager.gd                 Crystal meter, block counter, idle hint
  mission_file.gd                End-of-game reveal screen
  main.gd                        Title -> Level 1-3 -> Mission File flow
build.sh / build.bat        Generate assets + export the Web build
export_presets.cfg          HTML5 "Web" export preset
```

## Design constraints (for future contributors)

- No imported art/audio files — everything is generated via `Image`/`AudioStreamWAV` APIs.
- No keyboard `InputMap` entries — touch (and mouse-as-touch for desktop testing) only.
- All touch targets are 80×80px or larger, with visible press feedback.
- No failure states: falling off the level below y=300 triggers a harmless "reboot" (white
  flash + spring back to last safe ground), never a game over.
