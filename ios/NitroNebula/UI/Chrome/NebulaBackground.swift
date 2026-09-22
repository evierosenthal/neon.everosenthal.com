import SwiftUI

/// The three blurred nebula blobs behind everything (styles.css:83-119),
/// on the slate-950 base.
struct NebulaBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                NeonColors.slate950
                Group {
                    Circle().fill(NeonColors.indigo600)
                        .frame(width: w * 0.6, height: h * 0.6)
                        .position(x: w * 0.2, y: h * 0.2)
                    Circle().fill(NeonColors.purple700)
                        .frame(width: w * 0.5, height: h * 0.5)
                        .position(x: w * 0.8, y: h * 0.65)
                    Circle().fill(NeonColors.emerald800)
                        .frame(width: w * 0.4, height: h * 0.4)
                        .position(x: w * 0.5, y: h * 0.6)
                }
                .blur(radius: 90)
                .blendMode(.screen)
                .opacity(0.4)
            }
            .compositingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
