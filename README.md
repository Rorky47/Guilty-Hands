# Guilty Hands — Godot 4 starter (Milestones 1–2)

A runnable skeleton for a social-deduction prototype where every player has a
secret objective that's suspicious to act on. This covers the *local* steps so
you can feel the loop before adding any networking.

Built for **Godot 4.x**, 2D. Uses Godot's built-in `ui_*` input actions
(arrow keys + Enter), so it runs with **zero Input Map setup**.

## Scene setup (do this once in the editor)

1. New Godot 4 project. Create a 2D scene named `Main` (root: `Node2D`) and set
   it as the main scene.

2. **GameManager**: add a child `Node` named `GameManager`, attach
   `game_manager.gd`.

3. **Player scene**: new scene, root `CharacterBody2D` named `Player`.
   - Add a `CollisionShape2D` child with a `CircleShape2D` (radius ~16).
   - (Optional) add a `Sprite2D` / `Polygon2D` so you can see it.
   - Attach `player.gd`, save as `player.tscn`, and instance one into `Main`.

4. **Chore scene**: new scene, root `Area2D` named `Chore`.
   - Add a `CollisionShape2D` child with a `CircleShape2D` (radius ~24).
   - Attach `chore.gd`, save as `chore.tscn`, and instance 3–4 into `Main`,
     spread around the room.

5. Press Play.
   - Arrow keys to move.
   - Stand on a chore and **hold Enter** — a green ring fills as you "work."
   - Watch the **Output** panel: your secret objective prints at round start,
     and the reveal prints when the timer ends. Drop `round_seconds` in the
     GameManager inspector to ~15 to test the loop quickly.

## What's intentionally NOT here yet

- **Networking** (milestone 4). Add it once the loop feels fun. The path is
  Godot's high-level multiplayer: `MultiplayerSpawner` + `MultiplayerSynchronizer`
  + RPCs. Use **GodotSteam** if you want friends-over-internet lobbies.
  ⚠️ When you do: keep each player's objective on the host and RPC it only to
  that one client. Never replicate secret objectives to everyone — a curious
  player can just read them.
- **Accusation + scoring** (milestone 5).
- **UI** — the prototype prints to the Output panel on purpose. Wire up Labels
  later; don't let UI slow down testing whether the core tension is fun.

## Build order

1. ✅ Local sandbox: move + fill chores (this).
2. ✅ Loop: timer + secret objective + reveal (this).
3. Real objectives: 4–6 with completion checks, each forcing a visible tell.
4. Networking: lobby, one player per peer, synced positions, **private** objectives.
5. Judgment: accusation action + scoring.
6. Content + polish: more objectives, rooms, art, juice.
