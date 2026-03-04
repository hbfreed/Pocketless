import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    var barColor: Color = .red

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                let maxBars = Int(geometry.size.width / 4)
                let displaySamples = Array(samples.suffix(maxBars))

                ForEach(Array(displaySamples.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor)
                        .frame(width: 2, height: max(2, CGFloat(sample) * geometry.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
