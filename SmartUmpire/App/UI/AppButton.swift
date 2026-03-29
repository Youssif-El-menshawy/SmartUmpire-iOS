import SwiftUI

struct AppButton: View {
    enum Variant {
        case primary
        case secondary
        case destructive
        case ghost
    }

    let title: String
    let variant: Variant
    let icon: String?
    let isLoading: Bool
    let isFullWidth: Bool
    let action: () -> Void

    init(
        _ title: String,
        variant: Variant = .primary,
        icon: String? = nil,
        isLoading: Bool = false,
        isFullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.icon = icon
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.action = action
    }

    var body: some View {
        Button {
            if !isLoading {
                action()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if let icon {
                    Image(systemName: icon)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: 52)
            .padding(.horizontal, isFullWidth ? 0 : 16)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 1)
            )
            .cornerRadius(12)
            .opacity(isLoading ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.15), value: isLoading)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isLoading ? "Loading" : "")
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return .primaryBlue
        case .destructive:
            return .errorRed
        case .secondary:
            return Color.cardBackground
        case .ghost:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .textPrimary
        case .ghost:
            return .primaryBlue
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary:
            return .border
        case .ghost:
            return .primaryBlue.opacity(0.5)
        default:
            return .clear
        }
    }
}

extension AppButton {
    static func primary(_ text: String,
                        icon: String? = nil,
                        loading: Bool = false,
                        isFullWidth: Bool = true,
                        action: @escaping () -> Void) -> AppButton {
        AppButton(text,
                  variant: .primary,
                  icon: icon,
                  isLoading: loading,
                  isFullWidth: isFullWidth,
                  action: action)
    }
    
    static func secondary(_ text: String,
                          icon: String? = nil,
                          loading: Bool = false,
                          action: @escaping () -> Void) -> AppButton {
        AppButton(text, variant: .secondary, icon: icon, isLoading: loading, action: action)
    }

    static func destructive(_ text: String,
                            icon: String? = nil,
                            loading: Bool = false,
                            action: @escaping () -> Void) -> AppButton {
        AppButton(text, variant: .destructive, icon: icon, isLoading: loading, action: action)
    }
    
    static func ghost(_ text: String,
                      icon: String? = nil,
                      loading: Bool = false,
                      action: @escaping () -> Void) -> AppButton {
        AppButton(text, variant: .ghost, icon: icon, isLoading: loading, action: action)
    }
}
