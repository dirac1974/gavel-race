# World images and track dressing (AAA Phase 4)

- Whole images for Beams, Textures, Decals and particles (not atlas rects) are drawn in
  `tools/ui/make_ui_svgs.py` (STRIP_NAMES), rendered to `assets/ui/png/`, and uploaded as Decals via
  `upload_assets.py` TEXTURES. They land in `UiImages`; AssetService publishes each as
  `ReplicatedStorage` attribute `UiSheet_<name>`. Read them with `shared/WorldArt.luau`
  (`image(name)`, `whenReady(name, fn)`); keep a plain-colour fallback until they arrive.
- A Front-face Decal mirrors from behind, so a one-sided flag image is drawn as a FaceCamera Beam
  (hinge Attachment0 -> tip Attachment1) with a design that survives a top-to-bottom flip.
- Beam sag: Attachments with X axis down (`CFrame.fromMatrix(p, down, +X)`), CurveSize0 = +sag,
  CurveSize1 = -sag. Parent an Attachment before setting WorldCFrame.
- The replay and finish-orbit side camera sits at outer rail + 12 (RaceState.sideRig): keep trackside
  props further out than that or below the shot.
- Motor6D.Transform overrides go in RunService.PreSimulation (after the Animator); reset to identity on
  release. Pure pose math lives in the module and takes injected deps so Lune can test it.
