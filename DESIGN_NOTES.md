# Design Handoff — "Escape the Hunter" (working title: *Guilty Hands*)

**For:** a game designer (Claude) picking this up to push the design forward.
**From:** the build so far. Everything described under "Current build" is implemented and runs.
**Engine:** Godot 4.7, 2D. Project lives at `~/guilty-hands`. Run with `godot --path ~/guilty-hands`.

---

## 1. One-line pitch

An asymmetric survival game: a band of **survivors** must finish a set of **tasks** to escape a space, while one **hunter** roams the same space trying to catch them. Doing a task pins you in place and exposed — so progress and safety are in direct tension.

**Status:** single-player vertical slice. One human survivor (arrow keys), one **AI** hunter, three tasks. Win = all tasks done. Lose = hunter touches you. This is the smallest loop that proves the core tension; it's meant to be *felt*, then expanded.

---

## 2. The core loop (playable today)

1. Survivor spawns center-screen; hunter spawns in a far corner and sits still for a 2 s head start.
2. Survivor runs to a **task** (a ring on the floor), stands on it, and **holds Enter** for ~2 s to fill it — a green arc shows progress.
3. While filling, you're stationary and the hunter is closing in. Filling all 3 → **YOU ESCAPED**. Hunter reaches you → **CAUGHT**. Either way the game freezes and **Enter** restarts.
4. A `Tasks 0/3` counter sits top-left.

**Why it's fun (the pillar to protect):** *progress requires vulnerability.* The only way to win forces you to stop moving and commit, right when stopping is most dangerous. Every design decision should sharpen that trade, not dull it.

---

## 3. Current build — mechanics & knobs

Grounding so design proposals stay realistic about what exists.

| Element | Implemented as | Notes |
|---|---|---|
| **Survivor** | blue square, arrow keys, `speed = 220` | built-in `ui_*` input, no remap needed |
| **Hunter** | red diamond, AI, beelines at `speed = 170` | slower than survivor → you can kite/outrun in a straight line |
| **Hunter catch** | distance check, `catch_distance = 30` | passes *through* the survivor (no shoving), catch is pure proximity |
| **Hunter delay** | `head_start = 2.0 s` | breathing room at round start |
| **Task** | hold `Enter`, `fill_time = 2.0 s` each | 3 of them, fixed positions; self-draws ring + progress arc |
| **Win / lose / restart** | all-tasks vs caught; `Enter` to replay | tree pauses on end; banner + counter drawn in code |
| **Space** | empty 1152×648, fixed camera | **no walls, no rooms, no obstacles yet** |
| **Players** | exactly 1 survivor + 1 hunter, local | **no networking, no multiple survivors yet** |

All hunter knobs (`speed`, `catch_distance`, `head_start`) and `fill_time` are exported — tunable live in the Inspector.

**Hard constraints right now:** local single-machine only; one human input scheme (arrows + Enter); no art (colored polygons); no audio; feedback is on-screen labels + Output prints.

---

## 4. Design lineage — what was here before (mine this!)

This started as **"Guilty Hands," a social-deduction game**, and pivoted to the hunter survival loop. The deduction layer was removed from code but the *ideas* are strong and may be worth fusing back in. Original premise:

> Every player gets a **secret objective** that is *suspicious to act on* — so pursuing your goal makes you look guilty. Mundane chores were the **cover story** that let you act without standing out. Round timer, then a reveal + accusations + scoring.

The original secret-objective list (great flavor, all force a *visible* tell):
- Be the ONLY player in the reactor room when time runs out.
- End the round holding the toolbox.
- Make the lights go out at least 3 times.
- Complete ZERO real chores — fake-work the entire round.
- Be standing right next to one specific player when time runs out.
- Get every other player to step into the kitchen at least once.

**Why this matters for you:** there's an untapped fusion — survivors who must *both* escape the hunter *and* secretly pursue a suspicious objective, or a hunter whose identity is **hidden among the players** (Among Us-style) rather than an obvious red diamond. The setting hints (reactor, toolbox, kitchen, lights) suggest a **derelict-station / facility** fiction that the abstract prototype hasn't committed to.

---

## 5. Open design decisions (the forks I want your call on)

These are the branch points that most shape the game. Pick directions and justify the tension trade-off.

1. **Who is the hunter?** Permanent AI / a known human 2nd player / a *hidden* player among the survivors (deduction). Each makes a very different game.
2. **How many survivors, and are they cooperative?** Solo, or 3–5 co-op survivors, or every-survivor-for-themselves with the secret-objective layer.
3. **Escape structure.** Win instantly on the last task (current), or tasks *power an exit* you must then reach (Dead by Daylight gates), or staged objectives.
4. **What is a "task," in fiction?** Currently abstract rings. Tie them to a setting and give each a distinct *tell* (noise, light, a fixed location the hunter learns to camp).
5. **Hunter's senses & counterplay.** Right now it has perfect knowledge and a straight-line path. Options: line-of-sight/vision cone, hearing (tasks make noise), losing track of hidden survivors, sabotage. Survivor counterplay: hiding spots, distractions, stuns, reviving a downed teammate.
6. **Failure granularity.** One touch = dead (current), or downs-and-revives, or limited lives, or "caught = slowed, not out."
7. **The map.** Empty arena vs rooms with walls, chokepoints, hiding spots, multiple exits. This is the single biggest lever on whether the chase is interesting.
8. **Name & tone.** "Guilty Hands" fit the deduction concept; does it fit a survival-horror hunt, or does the game want a new identity?

---

## 6. Direction menu (concrete moves, roughly cheap → ambitious)

A palette to pull from, not a roadmap:

- **Tune the chase** — adjust speed gap / head start / catch range until the kite-vs-commit decision feels knife-edge.
- **Exit gate** — finishing tasks opens an exit; reaching it is the real win. Adds a climactic final sprint.
- **Walls + a room or two** — turn the open field into a space with corners to break line of sight. Unlocks real chase play.
- **Hunter vision instead of omniscience** — a facing + cone; survivors can break sight and hide. Transforms the feel from "race" to "stalk."
- **Task tells** — each task emits noise/light that draws the hunter; spreads risk across the map.
- **Second human as the hunter (local WASD)** — the asymmetric multiplayer stepping-stone before networking.
- **Multiple co-op survivors + downs/revives** — social pressure, sacrifice plays.
- **Re-fuse social deduction** — secret objectives and/or a hidden hunter, blending the original premise with the hunt.

---

## 7. Reference touchstones

- **Dead by Daylight** — 1 killer vs 4 survivors, repair generators, powered exit gates, downs + hooks. The closest structural cousin.
- **Among Us** — tasks as cover, hidden antagonist, social deduction. Closest to the *original* concept.
- **Hello Neighbor / Alien: Isolation** — a single stalking AI with senses and learned behavior.
- **Pico Park / Lovers in a Dangerous Spacetime** — if survivors go co-op and tasks need teamwork.

---

## 8. What I'd like from you (the designer)

1. Take a position on the **Section 5 forks** — especially *who the hunter is* and *the map*, since everything hangs off those.
2. Propose a **tight v2 loop** (one page) that deepens the core tension without exploding scope — ideally something the current build can reach in a few focused steps.
3. Call out the **one mechanic** you think makes or breaks the fun, and how to prototype it cheaply.
4. Flag anything in the current build that *fights* the pillar in Section 2.

Keep proposals grounded in the constraints in Section 3 (local, polygon art, built-in inputs) unless you explicitly argue a constraint is worth breaking.
