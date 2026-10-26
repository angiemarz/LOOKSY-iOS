import SwiftUI

/// Manual crop: drag the corners or the whole frame.
struct ImageCropView: View {
    let image: UIImage
    var onCrop: (CGRect) -> Void
    @Environment(\.dismiss) private var dismiss

    /// Crop rect in normalized image coordinates.
    @State private var rect = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
    @State private var dragStartRect: CGRect?

    private let minSize: CGFloat = 0.1

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let fitted = fittedSize(in: proxy.size)
                ZStack {
                    Color.black.ignoresSafeArea()
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: fitted.width, height: fitted.height)
                        cropOverlay(size: fitted)
                    }
                    .frame(width: fitted.width, height: fitted.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Recortar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        onCrop(rect)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Restablecer") {
                        rect = CGRect(x: 0, y: 0, width: 1, height: 1)
                    }
                }
            }
        }
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        let available = CGSize(width: container.width - 32, height: container.height - 32)
        let ratio = image.size.width / max(image.size.height, 1)
        if available.width / max(available.height, 1) > ratio {
            return CGSize(width: available.height * ratio, height: available.height)
        }
        return CGSize(width: available.width, height: available.width / ratio)
    }

    private func cropOverlay(size: CGSize) -> some View {
        let frame = CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
        return ZStack(alignment: .topLeading) {
            // Dim outside the crop area.
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRect(frame)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .contentShape(Rectangle())
                .offset(x: frame.minX, y: frame.minY)
                .gesture(moveGesture(size: size))
                .accessibilityLabel("Área de recorte")

            ForEach(Corner.allCases, id: \.self) { corner in
                let point = corner.point(in: frame)
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .shadow(radius: 2)
                    .position(point)
                    .gesture(cornerGesture(corner, size: size))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func moveGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartRect ?? rect
                if dragStartRect == nil { dragStartRect = rect }
                var newRect = start
                newRect.origin.x = min(max(start.minX + value.translation.width / size.width, 0), 1 - start.width)
                newRect.origin.y = min(max(start.minY + value.translation.height / size.height, 0), 1 - start.height)
                rect = newRect
            }
            .onEnded { _ in dragStartRect = nil }
    }

    private func cornerGesture(_ corner: Corner, size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartRect ?? rect
                if dragStartRect == nil { dragStartRect = rect }
                let dx = value.translation.width / size.width
                let dy = value.translation.height / size.height
                var minX = start.minX, minY = start.minY, maxX = start.maxX, maxY = start.maxY
                switch corner {
                case .topLeading:
                    minX = min(max(start.minX + dx, 0), maxX - minSize)
                    minY = min(max(start.minY + dy, 0), maxY - minSize)
                case .topTrailing:
                    maxX = max(min(start.maxX + dx, 1), minX + minSize)
                    minY = min(max(start.minY + dy, 0), maxY - minSize)
                case .bottomLeading:
                    minX = min(max(start.minX + dx, 0), maxX - minSize)
                    maxY = max(min(start.maxY + dy, 1), minY + minSize)
                case .bottomTrailing:
                    maxX = max(min(start.maxX + dx, 1), minX + minSize)
                    maxY = max(min(start.maxY + dy, 1), minY + minSize)
                }
                rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }
            .onEnded { _ in dragStartRect = nil }
    }

    private enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        func point(in frame: CGRect) -> CGPoint {
            switch self {
            case .topLeading: return CGPoint(x: frame.minX, y: frame.minY)
            case .topTrailing: return CGPoint(x: frame.maxX, y: frame.minY)
            case .bottomLeading: return CGPoint(x: frame.minX, y: frame.maxY)
            case .bottomTrailing: return CGPoint(x: frame.maxX, y: frame.maxY)
            }
        }
    }
}
