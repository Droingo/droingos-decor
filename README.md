# Droingo's Decor

Bare NeoForge 1.21.1 workspace converted from the Pod Racing Addon project.

## Included

- NeoForge 1.21.1 / Java 21
- Create 6.0.10
- Sable 1.2.1
- Create Aeronautics 1.2.1 (`simulated` mod dependency)
- Clean `net.droingo.decor` package
- Empty client renderer registration point
- Isolated Sable compatibility package
- Bobblehead Parrot model and texture
- Pre-split bobblehead body/head model files for later spring animation

## First implementation milestone

1. Create the reusable tiny-decor container.
2. Support four quarter-block surface slots.
3. Store per-entry facing/rotation.
4. Render `bobble_parrot_body` statically.
5. Render `bobble_parrot_head` around its neck pivot with a client-side damped spring.
6. Feed the spring from cached Sable sublevel acceleration while keeping replay playback deterministic.

Run `gradlew.bat build` in the IntelliJ terminal to verify the workspace.
