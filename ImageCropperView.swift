import SwiftUI

// MARK: - Legacy Alias for Compatibility
typealias ImageCropperView = ModernImageCropperView

struct ModernImageCropperView: View {
    let image: UIImage
    var onCropped: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Transform States
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    
    // MARK: - Gesture States
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    
    // MARK: - UI States
    @State private var showInstructions = true
    
    // MARK: - Constants
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    private let cropRatio: CGFloat = 1.0 // Square crop for FitSpo

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Image cropping area
                    GeometryReader { geometry in
                        let frameWidth = geometry.size.width
                        let frameHeight = frameWidth * cropRatio
                        
                        ZStack {
                            // Image container with gestures
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: frameWidth, height: frameHeight)
                                .offset(x: offset.width + dragOffset.width,
                                        y: offset.height + dragOffset.height)
                                .scaleEffect(scale * pinchScale)
                                .clipped()
                                .contentShape(Rectangle()) // Ensure the entire area is tappable
                                .gesture(
                                    SimultaneousGesture(
                                        DragGesture()
                                            .updating($dragOffset) { value, state, _ in
                                                state = value.translation
                                            }
                                            .onEnded { value in
                                                // Accumulate the offset
                                                offset.width += value.translation.width
                                                offset.height += value.translation.height
                                            },
                                        MagnificationGesture()
                                            .updating($pinchScale) { value, state, _ in
                                                state = value
                                            }
                                            .onEnded { value in
                                                // Accumulate the scale
                                                let newScale = scale * value
                                                scale = min(maxScale, max(minScale, newScale))
                                            }
                                    )
                                )
                            
                            // Crop overlay (non-interactive)
                            CropOverlay()
                                .allowsHitTesting(false) // This prevents the overlay from blocking gestures
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Bottom controls
                    VStack(spacing: 24) {
                        // Instructions
                        if showInstructions {
                            VStack(spacing: 8) {
                                HStack(spacing: 16) {
                                    InstructionItem(
                                        icon: "hand.draw",
                                        text: "Drag to move"
                                    )
                                    
                                    InstructionItem(
                                        icon: "magnifyingglass",
                                        text: "Pinch to zoom"
                                    )
                                }
                                
                                Text("Perfect your photo for FitSpo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showInstructions = false
                                }
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            // Reset button
                            Button(action: resetTransform) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Reset")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.2))
                                )
                            }
                            
                            // Next button
                            Button(action: {
                                if let cropped = cropImage() {
                                    onCropped(cropped)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text("Next")
                                        .font(.system(size: 16, weight: .semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue)
                                )
                            }
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
            }
        }
    }
    
    private func resetTransform() {
        withAnimation(.easeInOut(duration: 0.3)) {
            offset = .zero
            scale = 1.0
        }
    }
    
    private func cropImage() -> UIImage? {
        let displayScale = scale * pinchScale
        let finalOffset = CGSize(
            width: offset.width + dragOffset.width,
            height: offset.height + dragOffset.height
        )
        
        // Calculate crop area for square aspect ratio
        let cropSize = min(image.size.width, image.size.height)
        let cropX = (image.size.width - cropSize) / 2 - finalOffset.width / displayScale
        let cropY = (image.size.height - cropSize) / 2 - finalOffset.height / displayScale
        
        let cropRect = CGRect(
            x: max(0, cropX),
            y: max(0, cropY),
            width: min(cropSize, cropSize / displayScale),
            height: min(cropSize, cropSize / displayScale)
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Crop Overlay
struct CropOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width // Square crop
            
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.6)
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
                
                // Grid lines (optional, for better composition)
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { _ in
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .frame(height: 1)
                        Spacer()
                    }
                }
                .frame(width: width, height: height)
                
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { _ in
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .frame(width: 1)
                        Spacer()
                    }
                }
                .frame(width: width, height: height)
            }
        }
    }
}

// MARK: - Instruction Item
struct InstructionItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
