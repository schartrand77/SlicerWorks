# SlicerWorks

SlicerWorks is an iPad-specific 3D printing slicer app concept focused on:

- **Flagship iPad Pro UX** (touch-first + large-canvas workflows)
- **Apple Pencil Pro integration** (squeeze + barrel-roll-ready painting model)
- **Bambu Lab printers first** (A1/P1/X1 family profiles)
- **Bambu Studio-like workflow parity** in a native tablet experience

## What is implemented in this scaffold

- SwiftUI app entry point and tab navigation (`Slice`, `Paint`, `Devices`)
- Core app store/state container for project + printer + pencil state
- Bambu printer profile domain models
- Slicing and printer upload service protocols (with mock implementations)
- Apple Pencil-oriented painting tool model and placeholder painting surface
- Product brief with roadmap and implementation direction

## Project structure

- `ios/SlicerWorksApp/Core` — app state and shared domain models
- `ios/SlicerWorksApp/Features/Slicing` — slicing engine abstraction
- `ios/SlicerWorksApp/Features/DeviceIntegration` — printer upload abstraction
- `ios/SlicerWorksApp/Features/Painting` — painting tool definitions and view
- `ios/SlicerWorksApp/UI` — primary app screens
- `docs` — planning and product documentation

## Next engineering steps

1. Add a real iPad Xcode project/workspace and targets.
2. Replace painting viewport placeholder with Metal + mesh interaction.
3. Implement Bambu Studio-compatible slicing parameter mapping.
4. Integrate local-network Bambu printer discovery and upload.
5. Add project file import/export (`.3mf`, `.stl`, `.obj`) and history/undo.
