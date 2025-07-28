import SwiftUI

struct PlanBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .fontWeight(.bold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(.ultraThinMaterial))
    }
}
