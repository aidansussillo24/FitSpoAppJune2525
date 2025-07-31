import SwiftUI

// MARK: - Legacy Alias for Compatibility
typealias ImageCropperView = ModernImageCropperView

struct ModernImageCropperView: View {
    let image: UIImage
    var onCropped: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var selectedAspectRatio: AspectRatio = .square
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0

    enum AspectRatio: CaseIterable {
        case original, square, portrait, landscape
        
        var ratio: CGFloat {
            switch self {
            case .original: return 0
            case .square: return 1.0
            case .portrait: return 1.25 // 4:5
            case .landscape: return 0.8 // 5:4
            }
        }
        
        var name: String {
            switch self {
            case .original: return "Original"
            case .square: return "Square"
            case .portrait: return "Portrait"
            case .landscape: return "Landscape"
            }
        }
        
        var icon: String {
            switch self {
            case .original: return "rectangle"
            case .square: return "square"
            case .portrait: return "rectangle.portrait"
            case .landscape: return "rectangle.landscape"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Image area
                    GeometryReader { geometry in
                        let frameWidth = geometry.size.width
                        let frameHeight = selectedAspectRatio.ratio == 0 ? 
                            frameWidth * (image.size.height / image.size.width) :
                            frameWidth * selectedAspectRatio.ratio
                        
                        ZStack {
                            // Image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: frameWidth, height: frameHeight)
                                .offset(x: offset.width + dragOffset.width,
                                        y: offset.height + dragOffset.height)
                                .scaleEffect(scale * pinchScale)
                                .gesture(
                                    DragGesture()
                                        .updating($dragOffset) { value, state, _ in
                                            state = value.translation
                                        }
                                        .onEnded { value in
                                            offset.width += value.translation.width
                                            offset.height += value.translation.height
                                        }
                                )
                                .gesture(
                                    MagnificationGesture()
                                        .updating($pinchScale) { value, state, _ in
                                            state = value
                                        }
                                        .onEnded { value in
                                            scale *= value
                                        }
                                )
                                .clipped()
                            
                            // Crop overlay
                            CropOverlay(aspectRatio: selectedAspectRatio.ratio)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Controls
                    VStack(spacing: 20) {
                        // Aspect ratio selector
                        VStack(spacing: 12) {
                            Text("Aspect Ratio")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedAspectRatio = ratio
                                            resetTransform()
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: ratio.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(selectedAspectRatio == ratio ? .blue : .white)
                                            
                                            Text(ratio.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(selectedAspectRatio == ratio ? .blue : .white.opacity(0.7))
                                        }
                                        .frame(width: 60, height: 60)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedAspectRatio == ratio ? 
                                                      Color.blue.opacity(0.2) : 
                                                      Color.white.opacity(0.1))
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Instructions
                        VStack(spacing: 8) {
                            Text("Drag to move • Pinch to zoom")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Tap aspect ratio to change crop shape")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        if let cropped = cropImage() {
                            onCropped(cropped)
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func resetTransform() {
        offset = .zero
        scale = 1.0
    }
    
    private func cropImage() -> UIImage? {
        let displayScale = scale * pinchScale
        let finalOffset = CGSize(
            width: offset.width + dragOffset.width,
            height: offset.height + dragOffset.height
        )
        
        // Calculate crop area
        let cropWidth = image.size.width
        let cropHeight = selectedAspectRatio.ratio == 0 ? 
            image.size.height :
            image.size.width * selectedAspectRatio.ratio
        
        let cropX = (cropWidth - cropWidth / displayScale) / 2 - finalOffset.width / displayScale
        let cropY = (cropHeight - cropHeight / displayScale) / 2 - finalOffset.height / displayScale
        
        let cropRect = CGRect(
            x: max(0, cropX),
            y: max(0, cropY),
            width: min(cropWidth, cropWidth / displayScale),
            height: min(cropHeight, cropHeight / displayScale)
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Crop Overlay
struct CropOverlay: View {
    let aspectRatio: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = aspectRatio == 0 ? 
                width * (geometry.size.height / geometry.size.width) :
                width * aspectRatio
            
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(width: width, height: height)
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // Crop frame
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: width, height: height)
                
                // Corner indicators
                ForEach(0..<4, id: \.self) { corner in
                    CropCorner(corner: corner)
                        .frame(width: 20, height: 20)
                        .position(
                            x: corner % 2 == 0 ? 10 : width - 10,
                            y: corner < 2 ? 10 : height - 10
                        )
                }
            }
        }
    }
}

// MARK: - Crop Corner
struct CropCorner: View {
    let corner: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
            
            Circle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 6, height: 6)
        }
    }
}
