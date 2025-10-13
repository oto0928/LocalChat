import SwiftUI

// MARK: - Color Theme
struct AppColors {
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let secondaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.8)
    static let accentPurple = Color(red: 0.5, green: 0.0, blue: 1.0)
    static let successGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warningOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let errorRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    static let backgroundGray = Color(.systemGray6)
    static let cardBackground = Color(.systemBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppColors.primaryBlue, AppColors.secondaryBlue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(AppColors.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.backgroundGray)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GameButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Custom Card Style
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Custom Text Styles
extension Text {
    func titleStyle() -> some View {
        self
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(AppColors.textPrimary)
    }
    
    func subtitleStyle() -> some View {
        self
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.textPrimary)
    }
    
    func bodyStyle() -> some View {
        self
            .font(.body)
            .foregroundColor(AppColors.textPrimary)
    }
    
    func captionStyle() -> some View {
        self
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
    }
}

// MARK: - Custom Icon Styles
struct IconStyle: ViewModifier {
    let size: CGFloat
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
            .foregroundColor(color)
    }
}

extension Image {
    func iconStyle(size: CGFloat = 24, color: Color = AppColors.primaryBlue) -> some View {
        modifier(IconStyle(size: size, color: color))
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let status: ConnectionState
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

// MARK: - Loading Animation
struct LoadingDots: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppColors.primaryBlue)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

// MARK: - Custom Tab Bar Style
struct CustomTabBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accentColor(AppColors.primaryBlue)
            .onAppear {
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.systemBackground
                
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
    }
}

extension View {
    func customTabBarStyle() -> some View {
        modifier(CustomTabBarStyle())
    }
}

// MARK: - Game Board Styles
struct GameBoardStyle: ViewModifier {
    let backgroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundColor.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(backgroundColor.opacity(0.3), lineWidth: 2)
            )
    }
}

extension View {
    func gameBoardStyle(backgroundColor: Color = .blue) -> some View {
        modifier(GameBoardStyle(backgroundColor: backgroundColor))
    }
}

// MARK: - Message Bubble Styles
struct MessageBubbleStyle: ViewModifier {
    let isFromCurrentUser: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isFromCurrentUser ?
                LinearGradient(
                    gradient: Gradient(colors: [AppColors.primaryBlue, AppColors.secondaryBlue]),
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    gradient: Gradient(colors: [AppColors.backgroundGray, AppColors.backgroundGray]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)
            .cornerRadius(18)
    }
}

extension View {
    func messageBubbleStyle(isFromCurrentUser: Bool) -> some View {
        modifier(MessageBubbleStyle(isFromCurrentUser: isFromCurrentUser))
    }
}
