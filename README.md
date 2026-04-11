# SlicerWorks

SlicerWorks is an iPad-specific 3D printing slicer app concept focused on:

- **Flagship iPad Pro UX** (touch-first + large-canvas workflows)
- **Apple Pencil Pro integration** (squeeze + barrel-roll-ready painting model)
- **Bambu Lab printers first** (A1/P1/X1 family profiles)
- **Bambu Studio-like workflow parity** in a native tablet experience

## What is implemented in this scaffold

- SwiftUI app entry point and tab navigation (`Slice`, `Paint`, `Devices`)
- Core app store/state container for project, printer, and pencil state
- Typed app environment and operation status models for slice, upload, and project flows
- Bambu printer profile domain models
- Slicing and printer upload service protocols (with mock implementations)
- Serializable project document model with local last-project persistence scaffolding
- Project autosave hooks and validation coverage for core project settings
- File import scaffolding for `.stl`, `.obj`, and `.3mf`
- LAN Bambu printer discovery and known-printer persistence scaffolding
- Runnable iOS Xcode project and XCTest targets under `ios/SlicerWorks`
- Apple Pencil-oriented painting tool model and placeholder painting surface
- Product brief with roadmap and implementation direction

## Project structure

- `ios/SlicerWorks/SlicerWorks.xcodeproj` - canonical Xcode project and `SlicerWorks` scheme
- `ios/SlicerWorks/Config` - app plist/configuration files
- `ios/SlicerWorksApp/Core` - app state, environment, status, and shared domain models
- `ios/SlicerWorksApp/Features/Projects` - project document and persistence services
- `ios/SlicerWorksAppTests` - XCTest coverage for store, validation, and persistence logic
- `ios/SlicerWorksApp/Features/Slicing` - slicing engine abstraction
- `ios/SlicerWorksApp/Features/DeviceIntegration` - printer upload abstraction
- `ios/SlicerWorksApp/Features/Painting` - painting tool definitions and view
- `ios/SlicerWorksApp/UI` - primary app screens
- `docs` - planning and product documentation

## Build and test

Open the runnable project in Xcode:

```sh
open ios/SlicerWorks/SlicerWorks.xcodeproj
```

Run the local simulator test suite:

```sh
xcodebuild test -project ios/SlicerWorks/SlicerWorks.xcodeproj -scheme SlicerWorks -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.2'
```

If the Simulator is already open or a prior test run left cloned devices behind, close or shut down the existing simulator session before rerunning this command.

## Next engineering steps

1. Finish repository consolidation by removing stale duplicate app/test trees from the nested project area.
2. Extend validation beyond core settings into imported geometry and printer bounds.
3. Replace painting viewport placeholder with Metal + mesh interaction.
4. Implement Bambu Studio-compatible slicing parameter mapping.
5. Add authenticated Bambu printer connection and send-to-printer flow for real slice artifacts.

## Planning docs

- `docs/PRODUCT_BRIEF.md` - product framing and current scope
- `docs/ROADMAP.md` - phased engineering roadmap and delivery priorities

## Test coverage

- `ios/SlicerWorksAppTests/Core/AppStatusTests.swift` - status messaging and working-state behavior
- `ios/SlicerWorksAppTests/Core/AppStoreTests.swift` - slice, upload, load, and save state transitions
- `ios/SlicerWorksAppTests/Features/Projects/ProjectImportingTests.swift` - file import behavior
- `ios/SlicerWorksAppTests/Features/Projects/ProjectRepositoryTests.swift` - document persistence round-trip coverage
- `ios/SlicerWorksAppTests/Features/Projects/ProjectValidatorTests.swift` - project validation rule coverage
- `ios/SlicerWorksAppTests/UI/WorkspaceCameraTests.swift` - viewport camera transform behavior

These tests are attached to the `SlicerWorksTests` target in `ios/SlicerWorks/SlicerWorks.xcodeproj`.
