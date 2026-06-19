import SwiftUI

/// The placeholder avatar: a stylised human silhouette standing on a soft ground
/// shadow, with a dashed "spot" marking where the real avatar will live. Real
/// avatars and items come later; this shows the placement, scale and shadow.
struct MannequinView: View {
    /// Scale factor relative to the reference size (160 x 166).
    var scale: CGFloat = 1.0
    var showSpot: Bool = true
    var ringColor: Color?

    var body: some View {
        let headD = 42 * scale
        let torsoW = 66 * scale
        let torsoH = 72 * scale
        let torso = UnevenRoundedRectangle(
            topLeadingRadius: 26 * scale,
            bottomLeadingRadius: 12 * scale,
            bottomTrailingRadius: 12 * scale,
            topTrailingRadius: 26 * scale
        )

        ZStack(alignment: .bottom) {
            if showSpot {
                Ellipse()
                    .stroke(Theme.faint, style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .frame(width: 120 * scale, height: 26 * scale)
                    .offset(y: -2 * scale)
            }
            Ellipse()
                .fill(RadialGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.0)],
                    center: .center, startRadius: 0, endRadius: 55 * scale))
                .frame(width: 104 * scale, height: 20 * scale)
                .offset(y: -6 * scale)

            VStack(spacing: 7 * scale) {
                Circle()
                    .fill(Theme.surface2)
                    .overlay(Circle().stroke(ringColor ?? Theme.faint, lineWidth: 1))
                    .frame(width: headD, height: headD)
                torso
                    .fill(Theme.surface2)
                    .overlay(torso.stroke(ringColor ?? Theme.faint, lineWidth: 1))
                    .frame(width: torsoW, height: torsoH)
            }
            .offset(y: -16 * scale)
        }
        .frame(width: 160 * scale, height: 166 * scale)
    }
}
