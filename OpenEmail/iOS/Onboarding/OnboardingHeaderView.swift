import SwiftUI

struct OnboardingHeaderView: View {
    var height: CGFloat = 250

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.accentColor.opacity(0.4), location: 0),
                        .init(color: Color.accentColor.opacity(0.0), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height)

                Image(.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(250, geometry.size.width / 2))
            }
            .offset(y: geometry.frame(in: .global).minY > 0 ? -geometry.frame(in: .global).minY : 0)
        }
        .padding(.bottom, height)
    }
}

#Preview {
    ScrollView {
        VStack {
            OnboardingHeaderView()
            Text("Hello")
        }
    }
}
 
