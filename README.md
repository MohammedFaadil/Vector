<div align="center">

# ⚫ VECTOR: SHADOW RUNNER

**A cinematic 2.5D silhouette parkour runner — run, vault, slide, wall-run. Escape the grid.**

![Engine](https://img.shields.io/badge/Engine-Godot%204.3-478cbf?logo=godotengine&logoColor=white)
![Language](https://img.shields.io/badge/Language-GDScript-355570)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078d6?logo=windows&logoColor=white)
![Performance](https://img.shields.io/badge/Target-60%20FPS%20%40%201080p-2ea44f)
![Assets](https://img.shields.io/badge/External%20Assets-Zero-orange)
![License](https://img.shields.io/badge/License-MIT-green)

*A black shadow man auto-runs through backlit rooftop cityscapes — chaining jumps, slides,
rolls, vaults, wall-runs and ledge-climbs while the city gets faster and deadlier.
Inspired by the movement feel of **Vector 2**.*

</div>

---

## 📖 Table of Contents

- [Highlights](#-highlights)
- [Requirements](#-requirements)
- [How to Run (any PC)](#-how-to-run-any-pc)
- [Controls & How to Play](#-controls--how-to-play)
- [Game Features](#-game-features)
- [Technology & Architecture](#-technology--architecture)
- [Project Structure](#-project-structure)
- [Performance Budget](#-performance-budget)
- [Upgrading the Art & Audio](#-upgrading-the-art--audio)
- [Tuning & Modding Guide](#-tuning--modding-guide)
- [The Story](#-the-story)
- [Troubleshooting](#-troubleshooting)

---

## ✨ Highlights

- 🏃 **11-state parkour engine** with mocap-grade feel tuning — coyote time, jump buffering, variable jump height, momentum preservation, auto-parkour with a *PERFECT*-timing reward system
- 🌆 **Fully procedural cinematic visuals** — 6-layer parallax skylines, volumetric god-rays, HDR bloom, drifting fog, film grain, chromatic aberration, per-theme color grading
- 🌗 **Three rotating level moods** — burnt-orange **Dusk**, rain-lashed **Storm**, and glowing **Neon Night**, crossfading seamlessly every 400 m
- ♾️ **Endless hand-authored generation** — ten obstacle chunk patterns weighted by a 3 km difficulty curve, spawned ahead and pooled behind (flat memory, forever)
- 🔊 **100 % synthesized audio** — every SFX and all four ambient soundtracks are generated at startup; the repo ships with *zero* binary assets
- 💾 **Complete game loop** — menus, pause, settings with quality presets, scoring, combos, story beats, persistent high scores, instant restart

> 🖼️ *Screenshots: run the game and press `F12` (Godot's screenshot key is not bound by default — use Win+Shift+S), then drop images into `docs/` and link them here.*

---

## 💻 Requirements

| | Minimum | Recommended |
|---|---|---|
| **OS** | Windows 10 64-bit | Windows 11 |
| **GPU** | Any Vulkan-capable GPU (GTX 900 series+) | RTX 4050 or better |
| **VRAM** | 1 GB | 2 GB+ (game itself uses near-zero VRAM) |
| **RAM** | 4 GB | 8 GB+ |
| **Disk** | ~150 MB (engine + project) | — |

The game targets a **locked 60 FPS at 1920×1080** on an RTX 4050 laptop and reaches it with enormous headroom — all visuals are vector-drawn, so there are almost no textures to store or sample.

---

## 🚀 How to Run (any PC)

### Option A — One command (recommended)

Install [Git for Windows](https://git-scm.com/downloads) (gives you Git Bash), then from inside the project folder:

```bash
./setup.sh          # downloads Godot 4.3 into ./engine and opens the editor → press F5
./setup.sh play     # or launch the game directly, no editor
./setup.sh export   # or build a standalone build/VectorShadowRunner.exe
```

The script is idempotent — run it again anytime; it skips anything already downloaded.

### Option B — Manual (no bash needed)

1. Download **Godot 4.3 stable (Windows 64-bit)** — [godotengine.org/download/archive/4.3-stable](https://godotengine.org/download/archive/4.3-stable/) (the standard build, *not* .NET).
2. Unzip and run `Godot_v4.3-stable_win64.exe`.
3. In the Project Manager click **Import** → browse to this folder → select `project.godot` → **Import & Edit**.
4. Press **F5** (or the ▶ button, top-right). That's it.

### Option C — Standalone .exe (share with friends)

```bash
./setup.sh export
```

Produces `build/VectorShadowRunner.exe` — a single self-contained file (the game data is embedded). Copy it to any Windows PC and double-click. First run of `export` downloads Godot's export templates (~1 GB, one time).

> **Moving between PCs:** the whole project is plain text (~120 KB). Copy the folder, clone the repo, or zip it — then run `setup.sh` on the target machine. Nothing else to install.

---

## 🎮 Controls & How to Play

| Input | Action |
|---|---|
| `Space` / `W` / `↑` / Left-click | Jump · double-jump · wall-jump · climb from a ledge hang |
| `S` / `↓` / `Ctrl` **(hold)** | Slide under lasers · fast-fall in air · roll on hard landings |
| `Esc` / `P` | Pause |
| `R` | Instant restart |

**The rules of the roof:**

- 🔴 **Glowing = lethal.** Slide under laser fences, jump spike pits, never fall off the world.
- 📦 **Crates, low walls, tall walls** are handled *automatically* — the runner vaults, mantles and wall-runs on his own. But tapping **jump at the exact moment** an auto-move fires scores a **PERFECT** and stacks a speed boost — the heart of Vector 2's chase tension.
- 💥 **Hard landings must be rolled** — hold slide (or tap jump) just before a big impact to roll through it and *keep* your momentum; miss it and you stumble, bleeding speed.
- ✦ **Light shards** chain into combos when collected within 3 seconds of each other — combo score scales with the square of the chain.

---

## 🎯 Game Features

<details>
<summary><b>Movement & parkour (click to expand)</b></summary>

| Move | Trigger | Notes |
|---|---|---|
| Run | automatic | speed ramps 430 → 800 px/s over 3 km |
| Jump | tap jump | variable height — release early for a short hop |
| Double-jump | tap jump mid-air | resets on any surface contact |
| Coyote jump | jump ≤ 0.12 s after leaving a ledge | invisible forgiveness window |
| Buffered jump | jump ≤ 0.15 s before landing | fires the frame you touch down |
| Slide | hold slide | low profile clears lasers; keeps ~92 % of speed |
| Fast-fall | hold slide mid-air | 2.1× gravity slam |
| Roll | slide/jump held on a hard landing | converts impact into a speed *bonus* |
| Vault | automatic at crates | perfect-timing eligible |
| Mantle | automatic at low walls | perfect-timing eligible |
| Wall-run | automatic at tall walls | ~160 px of vertical gain |
| Wall-jump | tap jump during wall-run | huge vertical kick |
| Ledge-grab | automatic when a ledge is in reach mid-air | hangs briefly |
| Climb | tap jump while hanging (or auto) | tap = PERFECT bonus |
| Death | lasers, spikes, falling | slow-mo dissolve → results screen |

</details>

<details>
<summary><b>World generation</b></summary>

Ten authored chunk patterns — flat runs, gaps, vault crates, laser slide-unders, rising stairs, big drops, wall-run towers, spike pits, mid-air ledge towers, and a late-game triple-threat *gauntlet* — selected by weighted difficulty gating (a pattern never repeats twice in a row). Gap widths, wall heights and hazard density all scale with distance. Chunks spawn 2 600 px ahead of the camera and are freed 1 600 px behind it: memory usage is identical at 100 m and 100 km.

</details>

<details>
<summary><b>Presentation</b></summary>

- **Parallax depth rig:** screen-locked gradient sky → sun/moon with god-ray shader → three skyline strips at increasing parallax speed with atmospheric-perspective coloring → screen-space FBM fog.
- **Lighting model:** the world renders in HDR (`hdr_2d`); only pixels pushed above 1.0 brightness bloom — lasers, coins, the sun, lit windows. The pure-black runner gets a warm rim-light pass so he always reads against the sky.
- **Post stack** (one shader pass): vignette, animated film grain, radial chromatic aberration, per-theme lift/tint color grade, and speed-reactive tunnel vision.
- **Juice:** trauma-based screen shake (decays quadratically), look-ahead chase camera, run dust, landing bursts scaled by impact, perfect-move sparks, storm rain, motion-trail ghosts at sprint speed, slow-motion death dissolve.

</details>

<details>
<summary><b>Audio</b></summary>

A 12-voice pooled SFX engine over dedicated **Music / SFX buses** with a master limiter. Every sound — jumps, rolls, footsteps (pitch-randomized), coins, lasers, the death sting, UI ticks — is synthesized from raw waveforms at startup (`sfx_factory.gd`): sine sweeps, filtered noise, arpeggios, detuned drones. Each theme has its own seamless ambient chord pad, crossfaded on theme change. Swap any of it for real `.ogg` files without touching game code.

</details>

---

## 🛠 Technology & Architecture

| Layer | Implementation |
|---|---|
| Engine | Godot **4.3**, Forward+ renderer, HDR 2D pipeline |
| Physics | 120 Hz fixed tick; raycast-driven parkour detection (4 probes: vault / wall / clearance / ledge) |
| Rendering | 100 % procedural canvas drawing — one gradient texture in the whole game |
| Post-FX | 3 custom GLSL-style `gdshader`s (post stack, god-rays, FBM fog) |
| Audio | Runtime DSP synthesis → 16-bit WAV streams; bus architecture with limiter |
| Persistence | `ConfigFile` saves for settings + records in `user://` |
| Architecture | 4 autoload singletons (settings / audio / synth / game-state) + signal-driven scene composition, built entirely in code from a single stub scene |

**Design principles:** placeholder-free but asset-free; every system pooled or freed deterministically (no leaks in the endless loop); every "feel" number is a named constant; quality presets gate every expensive feature.

---

## 📁 Project Structure

```text
Vector/
├── project.godot                  # engine config, input map, autoloads, HDR renderer
├── scenes/main.tscn               # the only scene — everything is built in code
├── setup.sh                       # engine download · play · .exe export
├── scripts/
│   ├── main.gd                    # orchestrator: builds world, wires signals, game loop
│   ├── autoload/
│   │   ├── settings_manager.gd    # quality presets, volumes, fullscreen, persistence
│   │   ├── sfx_factory.gd         # synthesizes ALL audio at startup
│   │   ├── audio_manager.gd       # buses, 12-voice SFX pool, music crossfade
│   │   └── game_manager.gd        # run state, score/combo, themes, story, saves
│   ├── player/
│   │   ├── player.gd              # CharacterBody2D + 11-state parkour FSM
│   │   └── player_visual.gd       # procedural animated silhouette (+ sprite-sheet support)
│   ├── world/
│   │   ├── level_generator.gd     # endless chunk spawner / pooler + chunk library
│   │   ├── pieces.gd              # factories: platforms, walls, crates, lasers, coins
│   │   ├── themes.gd              # dusk / storm / neon mood definitions
│   │   └── hazard.gd · coin.gd · platform_visual.gd
│   ├── camera/game_camera.gd      # look-ahead chase cam + trauma shake
│   ├── fx/
│   │   ├── background.gd          # 6-layer parallax: sky, sun, rays, skylines, fog
│   │   └── effects.gd             # bloom, post-shader driver, particles, rain
│   └── ui/
│       ├── hud.gd                 # distance, score, combo, story beats, PERFECT flash
│       └── menus.gd               # main / pause / settings / game-over
└── shaders/
    ├── post_fx.gdshader           # vignette · grain · chromatic aberration · grade
    ├── god_rays.gdshader          # animated volumetric shafts
    └── fog.gdshader               # two-layer drifting FBM fog
```

---

## ⚡ Performance Budget

Engineered for **60 FPS @ 1080p on an RTX 4050 (6 GB) / 16 GB RAM** — and verified against these principles:

- **VRAM ≈ zero.** No sprite textures exist; silhouettes, buildings, particles and UI are all canvas-drawn primitives.
- **Flat memory forever:** world chunks are freed the moment they leave the camera; SFX voices are pooled; particles are one-shot and self-freeing.
- **Bloom is surgical:** `glow_hdr_threshold = 1.05` means only deliberately overbright pixels pay for glow.
- **Physics at 120 Hz** keeps raycast parkour rock-solid without touching render cost.
- **Quality presets** (Settings → Quality): LOW disables glow, post-FX, fog, god-rays and trails and quarters particle counts — for iGPU laptops; ULTRA raises particle density for high-end rigs.

---

## 🎨 Upgrading the Art & Audio

The game is deliberately structured so real production assets **drop in with zero code changes**:

1. **Character — Mixamo mocap silhouettes.** Render Mixamo parkour clips in Blender as pure-black sprite strips (one horizontal row per animation) into `art/player/`, named `<anim>_<frames>.png`:
   `run_12.png · jump_8.png · doublejump_8.png · fall_6.png · slide_6.png · roll_10.png · vault_8.png · wallrun_8.png · hang_4.png · climb_8.png · death_10.png`
   They're auto-detected at boot and replace the procedural skeleton ([player_visual.gd](scripts/player/player_visual.gd)).
2. **Backgrounds — AI-generated layers.** Generate 1920×1080 PNGs per theme (sky / far / mid / near skyline). Prompt recipe: *"distant city skyline silhouette at burnt-orange dusk, atmospheric haze, flat 2D side-scroller background layer, no foreground objects, minimalist"* — then swap them into the layers in [background.gd](scripts/fx/background.gd).
3. **Audio.** Drop `.ogg` files into the project and overwrite entries in `SfxFactory.sounds` / `SfxFactory.music` — the bus/pool/crossfade plumbing is format-agnostic.

---

## 🔧 Tuning & Modding Guide

| Want to change | Edit |
|---|---|
| Jump weight / float | `GRAVITY`, `JUMP_VELOCITY`, `FALL_GRAVITY_MULT` — [player.gd](scripts/player/player.gd) |
| Top speed / ramp length | `MAX_RUN_SPEED`; `difficulty()` divisor in [game_manager.gd](scripts/autoload/game_manager.gd) |
| Gap sizes, wall heights | per-chunk `lerpf(min, max, d)` ranges — [level_generator.gd](scripts/world/level_generator.gd) |
| Add an obstacle pattern | write a `_chunk_yourname()` and register it in the `CHUNKS` table |
| Add a theme / mood | new entry in [themes.gd](scripts/world/themes.gd) + `THEME_ORDER` in game_manager.gd |
| Theme length | `THEME_LENGTH_M` (default 400 m) |
| Timing-reward window | `PERFECT_WINDOW` (default 0.18 s) |
| Screen-shake intensity | trauma values in [effects.gd](scripts/fx/effects.gd) |

---

## 📜 The Story

> *They watch everyone. They caught you once. Not again — **RUN.***
>
> A nameless runner breaks out of the surveilled grid at dusk, crosses the storm
> district under sheets of rain, and races the neon night toward the edge of the
> city. The story unfolds in beats that fade over the skyline as you pass each
> distance marker — and it only ends when you stop running.

---

## ❓ Troubleshooting

| Problem | Fix |
|---|---|
| Black window / crash on start | Your GPU lacks Vulkan → in Godot: **Project → Project Settings → Rendering → Renderer** → `gl_compatibility`, or run with `--rendering-driver opengl3` |
| Stutter on a weak laptop | Settings → Quality → **LOW** |
| No sound | Check Windows output device; volumes live in Settings (saved to `user://settings.cfg`) |
| Reset high score / settings | Delete `%APPDATA%\Godot\app_userdata\Vector Shadow Runner\` |
| `setup.sh: command not found` | Run it from **Git Bash**, not cmd/PowerShell — or use [Option B](#option-b--manual-no-bash-needed) |
| Export fails | Re-run `./setup.sh export` (template download may have been interrupted) |

---

<div align="center">

**Built with Godot 4.3 · Designed and coded end-to-end with Claude**

*If you enjoy the run — ⭐ the repo.*

</div>
