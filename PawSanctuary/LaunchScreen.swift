import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.91, blue: 0.78),
                    Color(red: 0.83, green: 0.77, blue: 0.60)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 0.07, green: 0.28, blue: 0.16))
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)

                    VStack(spacing: 2) {
                        // House roof
                        Image(systemName: "house.fill")
                            .font(.system(size: 54))
                            .foregroundColor(Color(red: 0.91, green: 0.66, blue: 0.44))
                    }
                }

                VStack(spacing: 4) {
                    Text("Paw Sanctuary")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.07, green: 0.28, blue: 0.16))

                    Text("Rescue · Merge · Protect")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.07, green: 0.28, blue: 0.16).opacity(0.65))
                        .kerning(1.2)
                }
            }
        }
    }
}
