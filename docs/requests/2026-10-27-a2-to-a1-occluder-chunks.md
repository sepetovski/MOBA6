# Request: chunk occluders for the camera fade

- Date: 2026-10-27
- From: A2 (Camera and Input)
- To: A1 (World)
- Status: open. A2 carries on with a sandbox stub and does not edit `src/world/`.

## What

Tag every `GeometryInstance3D` that can hide a unit with the group `occluder_fade`:

- the south-side wall (the flat toward the camera, +Z)
- the stand rows nearest the camera
- any prop taller than 2.2 m

Build those walls and stands in chunks of at most 6 m, so `OcclusionFader` fades only the pieces whose world AABB crosses the camera-to-unit segment, not a whole 30 m wall.

## Why

`OcclusionFader` (`src/camera/occlusion_fader.gd`) only considers the `occluder_fade` group. `GeometryInstance3D.transparency` moves an instance to the transparent pipeline, so a single long wall would fade end to end and sort badly.

## Proposed signature

No new method. On each blocking mesh:

```gdscript
mesh_instance.add_to_group(&"occluder_fade")
```

Keep each chunk's world AABB no longer than 6 m on X or Z.
