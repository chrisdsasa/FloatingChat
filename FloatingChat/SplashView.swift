import SwiftUI

struct SplashView: View {
    @State private var opacity = 0.0
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background with gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 20) {
                // Logo
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    // Icon
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                }
                
                // App name
                Text("FloatingChat")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Tagline
                Text("Your AI assistant, one keystroke away")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, -5)
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top, 20)
            }
            .opacity(opacity)
        }
        .onAppear {
            // Fade in animation
            withAnimation(.easeIn(duration: 1.2)) {
                opacity = 1.0
            }
            
            // Dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Fade out animation
                withAnimation(.easeOut(duration: 0.8)) {
                    opacity = 0.0
                }
                
                // Call completion handler after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onComplete()
                }
            }
        }
    }
} 