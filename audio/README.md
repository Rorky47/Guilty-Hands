# Audio assets

Drop sound files here. Each is loaded by **base name**, accepting either
`.ogg` or `.wav` (`.ogg` is checked first). Any missing file is skipped
silently — the project always runs. Footstep and hunter sounds fall back to a
simple procedural tone (see `audio_lib.gd`) until you add real files; the rest
are silent when missing.

| Base name          | Loop | Used by                | Notes                                  |
|--------------------|------|------------------------|----------------------------------------|
| `footstep_walk`    | no   | player walking         | fires on the footstep tick             |
| `footstep_sprint`  | no   | player sprinting       | fires on the footstep tick             |
| `footstep_crouch`  | no   | player crouching       | low volume; audible but emits no noise |
| `land`             | no   | player landing a jump  | fires on the landing trigger           |
| `hunter_idle`      | yes  | hunter (always)        | quiet lurking growl/breath             |
| `hunter_move`      | yes  | hunter while moving    | volume scales with speed               |
| `hunter_alert`     | no   | hunter entering HUNTING | one-shot "found the trail" stinger     |
| `water_loop`       | yes  | flooded dead-end       | positional; proximity reveals it       |
| `ambient`          | yes  | global                 | non-positional, quiet bed              |

Looping streams are looped automatically (`.loop` on Ogg/MP3, loop points on
WAV). All 3D sources route through the reverb-carrying **SFX** bus.

For `.ogg`/`.wav` you usually don't need to touch import settings; if a WAV
won't loop cleanly, enable **Loop** in its Import tab.
