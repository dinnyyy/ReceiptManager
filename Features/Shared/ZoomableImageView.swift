import SwiftUI

/// Spec 5.8: "Tapping attachment opens full-screen preview." Shared by
/// Review's thumbnail and Purchase Detail's attachments carousel.
struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnificationGesture().onChanged { scale = max(1, $0) })
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
