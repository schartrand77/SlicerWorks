import SwiftUI

struct ModelPaintingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple Pencil Pro Painting")
                .font(.headline)

            Text("Use squeeze to toggle brush/fill and barrel roll to rotate brush angle.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Tool", selection: $store.selectedTool) {
                ForEach(PaintingTool.allCases) { tool in
                    Text(tool.title).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Label(store.pencilState.squeezeEnabled ? "Squeeze: On" : "Squeeze: Off", systemImage: "applepencil")
                Spacer()
                Text("Roll: \(Int(store.pencilState.barrelRollAngle))°")
            }
            .font(.caption)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 44))
                        Text("3D viewport placeholder")
                    }
                    .foregroundStyle(.secondary)
                }
        }
        .padding()
    }
}
