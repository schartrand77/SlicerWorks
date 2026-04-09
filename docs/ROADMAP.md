# SlicerWorks Roadmap

## Current State
SlicerWorks is currently an early iPad-first SwiftUI scaffold with:

- Root tab navigation for Slice, Paint, and Devices.
- Centralized app state in `AppStore`.
- Structured app environment and typed operation status handling.
- Bambu printer profile models for A1, A1 Mini, P1P, P1S, and X1 Carbon.
- Mock slicing and printer upload abstractions.
- Serializable project document, local persistence scaffolding, and autosave hooks.
- Project validation for core settings and supported source formats.
- Placeholder Apple Pencil Pro painting UI and tool model.

The main gap is that the app shell exists, but the production-grade slicing, 3D interaction, file handling, and printer connectivity layers are still missing.

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
- Add tests around domain logic as soon as non-mock behavior appears.

## Phase 0: Foundation Hardening
Target outcome: convert the scaffold into a buildable app foundation that can support real feature work.

### Work items
- Create a complete Xcode project/workspace with app target, schemes, and basic configuration.
- Complete: separate domain models, app services, and feature state to reduce future coupling in `AppStore`.
- Complete: add dependency injection boundaries for slicer, file import, persistence, and printer networking services.
- Complete: introduce error types and user-facing status models instead of raw strings in views.
- In progress: establish a test target for domain and service-layer coverage.

### Definition of done
- App builds and runs from Xcode without manual project reconstruction.
- Core services can be swapped between mock and real implementations cleanly.
- Basic unit tests exist for project state, slicing requests, and printer selection logic, and are wired into a runnable target.

## Current Test Coverage
- `AppStatus` coverage for message rendering and working-state transitions.
- `AppStore` coverage for slice success/failure, upload preconditions, upload success, and project load/save flows.
- `ProjectRepository` coverage for in-memory and `UserDefaults` document persistence round trips.
- `ProjectValidator` coverage for core model/settings validation rules.

The remaining gap is infrastructure: the repo still needs an actual Xcode test target or package-based test harness so the test suite can run in CI and locally without manual setup.

## Phase 1: Project Import and Persistence
Target outcome: users can open, save, and resume real print projects.

### Work items
- Add file import for `.stl`, `.obj`, and `.3mf`.
- Complete: create a project document model that stores source assets, settings, and painting metadata.
- Complete: implement local persistence scaffolding for recent projects and autosave.
- In progress: add project validation for missing files, unsupported geometry, and incompatible printer bounds.
- Add undo/redo support for settings and painting operations.

### Definition of done
- A model can be imported from Files, saved, reopened, and resumed.
- The app restores the last active project safely after restart.
- Invalid or unsupported project states fail with actionable errors.

## Phase 2: 3D Viewport and Interaction
Target outcome: replace placeholders with a real iPad-native model interaction surface.

### Work items
- Replace the placeholder painting surface with a Metal-backed viewport.
- Add camera controls optimized for touch and Apple Pencil input.
- Implement mesh loading, transforms, bounds display, and model positioning on the plate.
- Support face picking, hit testing, and region highlighting.
- Add selection overlays for paintable regions, seams, and support blockers.

### Definition of done
- Imported models render smoothly on target iPad hardware.
- Users can rotate, pan, zoom, and inspect geometry without input lag.
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

### Definition of done
- The app can produce real machine-ready output for at least one Bambu profile.
- Slice settings are reproducible and stored with the project.
- Users receive clear warnings for unsupported settings or print risks.

## Phase 5: Bambu Device Integration
Target outcome: a sliced job can move from iPad to printer with minimal friction.

### Work items
- Implement local network discovery for compatible Bambu printers.
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

## Immediate Next Sprint
Recommended next sequence for actual development:

1. Create the real Xcode project and test target.
2. Extend validation beyond core settings into imported geometry and printer bounds.
3. Replace the viewport placeholder with a real render pipeline.
4. Implement file import for `.stl`, `.obj`, and `.3mf`.
5. Introduce structured slice settings and printer preset mapping.
6. Start LAN device discovery only after a real slice artifact exists.

## Risks and Constraints
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
