# SlicerWorks Roadmap

## Current State
SlicerWorks is currently an early iPad-first SwiftUI scaffold with:

- Root tab navigation for Slice, Paint, and Devices.
- Centralized app state in `AppStore`.
- Structured app environment and typed operation status handling.
- Bambu printer profile models for A1, A1 Mini, P1P, P1S, and X1 Carbon.
- Mock slicing and printer upload abstractions.
- Serializable project document, local persistence scaffolding, and autosave hooks.
- Model import for `.3mf`, `.stl`, and `.obj` through the Slice workspace, with imported files copied into app storage.
- Project validation for core settings and supported source formats.
- Apple Pencil Pro-oriented painting tool model with a gesture-driven placeholder viewport.
- LAN Bambu printer discovery, add/select flow, and local known-printer persistence scaffolding.
- An always-on startup landing page that auto-scans LAN for newly detected Bambu printers, prompts for add with access code, and then hands off into the workspace.
- A runnable Xcode project and test targets in `ios/SlicerWorks`.

The main gap is no longer basic app bootstrapping. The app can build from the Xcode project at `ios/SlicerWorks/SlicerWorks.xcodeproj`, which points at `ios/SlicerWorksApp` and `ios/SlicerWorksAppTests` as the active app and test roots. The production-grade slicing, 3D interaction, file handling, and printer connectivity layers are still missing, and the repository still needs final cleanup of stale duplicate app/test folders inside the nested project area.

## Product Goal
Ship an iPad-native slicer that is strong enough to replace desktop-first workflows for common Bambu printing tasks:

- Import a real model.
- Configure print settings with confidence.
- Paint supports, seams, or materials with Apple Pencil Pro.
- Slice reliably with printer-correct presets.
- Send the job directly to a Bambu printer on the local network.

## Roadmap Principles
- Prioritize end-to-end usable workflows over isolated feature demos.
- Build the model pipeline and persistence layer before deep UI polish.
- Keep Bambu-first support tight before expanding printer compatibility.
- Treat the 3D viewport as core infrastructure, not a visual enhancement.
- Treat indirect input support as core UX: trackpad gestures should mirror touch behavior where the platform allows it.
- Add tests around domain logic as soon as non-mock behavior appears.

## Phase 0: Foundation Hardening
Target outcome: keep the runnable app foundation clean enough to support real feature work without duplicate implementation paths.

### Work items
- Complete: create a complete Xcode project/workspace with app target, schemes, and basic configuration.
- Complete: separate domain models, app services, and feature state to reduce future coupling in `AppStore`.
- Complete: add dependency injection boundaries for slicer, file import, persistence, and printer networking services.
- Complete: introduce error types and user-facing status models instead of raw strings in views.
- Complete: establish XCTest-based test targets for core store and project domain behavior.
- In progress: consolidate duplicate source trees so `ios/SlicerWorks/SlicerWorks.xcodeproj` is the single runnable project and `ios/SlicerWorksApp` / `ios/SlicerWorksAppTests` are the active source roots.
- In progress: wire local test execution into a documented, repeatable command:
  `xcodebuild test -project ios/SlicerWorks/SlicerWorks.xcodeproj -scheme SlicerWorks -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.2'`
- Resolve simulator launch instability before marking the command verified; the latest run built the targets but failed while launching simulator test clones with `NSMachErrorDomain Code=-308`.
- Add a CI-friendly variant of the test command once the stale nested source copy is removed.

### Definition of done
- App builds and runs from Xcode from a single canonical project layout.
- Core services can be swapped between mock and real implementations cleanly.
- Basic unit tests exist for project state, slicing requests, and printer selection logic, and are runnable without ambiguous duplicate test suites.

## Current Test Coverage
- `AppStatus` coverage for message rendering and working-state transitions.
- `AppStore` coverage for slice success/failure, upload preconditions, upload success, and project load/save flows.
- `ProjectRepository` coverage for in-memory and `UserDefaults` document persistence round trips.
- `ProjectValidator` coverage for core model/settings validation rules.

The remaining gap is execution discipline rather than test absence: the repo now has a canonical local test command, but still needs stale nested test files removed and CI added so coverage does not drift as real integrations replace mocks.

## Phase 1: Project Import and Persistence
Target outcome: users can open, save, and resume real print projects.

### Work items
- Complete: add file import for `.stl`, `.obj`, and `.3mf`.
- Complete: create a project document model that stores source assets, settings, and painting metadata.
- Complete: implement local persistence scaffolding for recent projects and autosave.
- In progress: add project validation for missing files, unsupported geometry, and incompatible printer bounds.
- Add explicit import pipeline types so file parsing, mesh validation, and project creation can evolve independently.
- Add undo/redo support for settings and painting operations.
- Decide whether `.3mf` is first-class editable project format, interchange format, or both.

### Definition of done
- A model can be imported from Files, saved, reopened, and resumed.
- The app restores the last active project safely after restart.
- Invalid or unsupported project states fail with actionable errors.
- Imported assets have a stable internal representation that later viewport and slicer work can reuse.

## Phase 2: 3D Viewport and Interaction
Target outcome: replace placeholders with a real iPad-native model interaction surface.

### Work items
- Replace the placeholder painting surface with a Metal-backed viewport.
- Add camera controls optimized for touch and Apple Pencil input.
- Add trackpad and pointer gesture support for orbit, pan, and pinch-to-zoom behavior aligned with touch expectations.
- Implement mesh loading, transforms, bounds display, and model positioning on the plate.
- Support face picking, hit testing, and region highlighting.
- Add selection overlays for paintable regions, seams, and support blockers.
- Keep the current gesture semantics only as a temporary UX baseline; do not let the SwiftUI placeholder camera contract become the long-term rendering API.

### Definition of done
- Imported models render smoothly on target iPad hardware.
- Users can rotate, pan, zoom, and inspect geometry without input lag.
- Trackpad users can navigate the viewport with the same core gesture vocabulary as touch users, including pinch zoom.
- The viewport exposes reliable picking data for painting and analysis tools.

## Phase 3: Apple Pencil Pro Painting Workflow
Target outcome: painting becomes a real differentiator rather than a placeholder feature.

### Work items
- Implement brush projection onto mesh surfaces.
- Support Smart Fill region detection and contiguous area selection.
- Add seam painting and support blocker authoring with visible overlays.
- Map Pencil Pro squeeze and barrel roll into tool switching, brush sizing, or angle control.
- Add paint-layer editing tools such as erase, isolate, invert, and clear selection.

### Definition of done
- Paint operations affect real model data and persist with the project.
- Pencil interactions feel deliberate and low-friction on supported hardware.
- Users can preview painting results before slicing.

## Phase 4: Slicing Engine Integration
Target outcome: generate real slice output for supported Bambu printer profiles.

### Work items
- Define a production slicing request model beyond layer height and infill.
- Add printer-specific preset mapping for nozzle sizes, bed limits, speeds, supports, and filament behavior.
- Integrate a real slicing backend behind `SlicerEngine`.
- Surface progress, cancellation, warnings, and slice result summaries.
- Validate generated output against selected printer capabilities and project bounds.
- Decide early whether the slicing backend is embedded native code, a wrapped existing engine, or a service boundary bridged into iPad app code.

### Definition of done
- The app can produce real machine-ready output for at least one Bambu profile.
- Slice settings are reproducible and stored with the project.
- Users receive clear warnings for unsupported settings or print risks.

## Phase 5: Bambu Device Integration
Target outcome: a sliced job can move from iPad to printer with minimal friction.

### Work items
- Complete: implement local network discovery for compatible Bambu printers.
- Complete: start every app session on a printer landing page that scans for newly detected LAN printers before entering the workspace.
- Add authenticated printer connection and secure credential handling.
- Show printer availability, selected device state, and upload progress.
- Support send-to-printer flow for sliced jobs.
- Investigate AMS metadata sync and printer capability reporting.

### Definition of done
- The app discovers at least one supported Bambu printer on LAN.
- A user can choose a device, upload a job, and receive success/failure feedback.
- Connection errors and offline states are recoverable inside the app.

## Phase 6: Workflow Quality and Release Readiness
Target outcome: the app is stable enough for structured beta use.

### Work items
- Add crash reporting and internal diagnostics hooks.
- Improve performance on large models and repeated project edits.
- Build onboarding for model import, painting, slicing, and printer send.
- Add regression coverage for import, persistence, slicing configuration, and upload flows.
- Run beta validation on target iPad Pro hardware and at least one supported Bambu device.

### Definition of done
- Core flows are stable across repeated sessions.
- Key regressions are caught by automated tests.
- Beta users can complete the primary workflow without developer intervention.

## Cross-Cutting Technical Tracks
These tracks should move in parallel with the phase roadmap rather than waiting for a single late cleanup pass.

### Repo and build hygiene
- Consolidate duplicate app and test trees so roadmap work lands in one place.
- Complete: document the canonical Xcode scheme, simulator target, and test command.
- Add CI to run unit tests on every branch once the canonical project layout is settled.

### Domain model maturity
- Separate import-time geometry data from user-authored project state.
- Define stable identifiers for meshes, faces, paint regions, and slice presets.
- Avoid letting UI placeholder types become de facto persistence formats.

### Performance budgets
- Set target budgets for model load time, viewport frame rate, and paint stroke latency.
- Validate performance on a realistic iPad Pro target before deep feature layering.
- Validate touch and trackpad interaction latency separately so indirect input does not become a second-class path.
- Add lightweight instrumentation before optimization work starts.

### Compatibility strategy
- Keep Bambu-first support explicit in model and preset design.
- Delay broad printer abstraction until one end-to-end Bambu workflow is reliable.
- Treat `.3mf` fidelity and Bambu protocol behavior as active research items, not solved assumptions.

## Immediate Next Sprint
Recommended next sequence for actual development:

1. Consolidate the repo so `ios/SlicerWorks` is the single canonical app and test target.
2. Document the local build/test path from that project and verify it after simulator state is clean.
3. Remove or archive the stale nested app/test copy after confirming no newer code exists there.
4. Extend validation from core settings into imported geometry and printer bounds.
5. Replace the placeholder viewport with a real render pipeline that can own picking and camera state.
6. Introduce structured slice settings and printer preset mapping.
7. Connect LAN device discovery to real slice artifacts through authenticated upload.

## Milestone View
Use these checkpoints to decide whether the roadmap is still moving toward a shippable app rather than accumulating disconnected scaffolding.

### Milestone A: Canonical foundation
- One app target, one test suite location, one documented way to build and test.
- Import-free demo project still works after consolidation.

### Milestone B: First real model workflow
- User imports a supported mesh, sees it in a real viewport, saves, reopens, and preserves project state.
- Validation catches unsupported geometry before slicing starts.

### Milestone C: First machine-ready slice
- At least one Bambu profile generates a reproducible slice artifact with intelligible warnings.
- Slice summaries and preset behavior are trustworthy enough for internal dogfooding.

### Milestone D: First printer handoff
- A sliced job is discoverable, selectable, and uploadable to a supported Bambu printer on LAN.
- Failure states are visible and recoverable without restarting the app.

## Risks and Constraints
- Duplicate source trees can waste roadmap effort if new work lands in the wrong app target.
- Slicing backend integration may be the largest technical dependency.
- Real-time mesh painting performance on iPad must be validated early.
- Bambu protocol details and authentication behavior may constrain upload reliability.
- `.3mf` support can become a hidden complexity if painting and metadata need round-trip fidelity.

## Success Metrics
- Time from model import to first successful slice.
- Time from slice completion to printer upload.
- Crash-free rate during import, viewport interaction, and slice flows.
- Median interaction latency during model navigation and painting.
- Percentage of project state that round-trips correctly through save and reopen.
