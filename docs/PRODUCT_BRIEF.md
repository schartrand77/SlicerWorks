# SlicerWorks Product Brief

## Vision
SlicerWorks is an iPad-first 3D printing slicer designed for **iPad Pro + Apple Pencil Pro** workflows. It begins with tight support for **Bambu Lab** printers and a UX that mirrors the high-value capabilities of Bambu Studio while adding touch- and pen-native controls.

## Phase 1 scope (current scaffold)
1. **Bambu-focused slicing flow**
   - Printer profiles for A1, A1 Mini, P1P, P1S, and X1 Carbon.
   - Single-project slicing settings (layer height, infill).
   - Asynchronous slice and upload pipeline abstractions.
2. **Apple Pencil Pro-first painting**
   - Paint Brush, Smart Fill, Seam Mask, Support Blocker tool slots.
   - Pencil state model prepared for squeeze and barrel roll.
3. **iPad navigation model**
   - App-owned root experience: Prepare for model layout and paint editing, then Slice as the action that advances to Print when gcode generation succeeds.
   - Print page focuses on printer selection, AMS color matching, and upload.

## Platform assumptions
- iPadOS 18+ target for Pencil Pro hardware features.
- SwiftUI app shell with room to integrate Metal-based 3D viewport.
- Slicer runtime is abstracted behind `SlicerEngine` so a native engine or wrapped backend can be integrated later.

## Near-term build plan
1. Replace placeholder 3D canvas with a Metal viewport.
2. Implement mesh face picking + brush projection for painting.
3. Add 3MF import/export and project persistence.
4. Integrate Bambu-compatible print profile presets and gcode flavor details.
5. Implement LAN printer discovery and authenticated send-to-printer.
