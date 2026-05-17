import SwiftUI

/// Appearance settings panel (font, size, spacing, theme).
struct AppearanceSheet: View {
    @EnvironmentObject var appState: AppState

    private var settings: Binding<ReaderSettings> {
        Binding(
            get: { appState.settingsStore.settings },
            set: { appState.settingsStore.settings = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("外观设置")
                .font(.title2)
                .fontWeight(.semibold)

            // Font Family
            VStack(alignment: .leading, spacing: 6) {
                Text("字体")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("", selection: settings.fontFamily) {
                    ForEach(ReaderSettings.availableFonts, id: \.self) { font in
                        Text(font)
                            .font(.custom(font, size: 14))
                            .tag(font)
                    }
                }
                .labelsHidden()
            }

            // Font Size
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("字号")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(settings.fontSize.wrappedValue))px")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Slider(value: settings.fontSize, in: 14...32, step: 1)
            }

            // Line Spacing
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("行距")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", settings.lineSpacing.wrappedValue))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Slider(value: settings.lineSpacing, in: 1.0...2.5, step: 0.1)
            }

            // Theme
            VStack(alignment: .leading, spacing: 6) {
                Text("主题")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ForEach(ReaderSettings.ReaderTheme.allCases) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: settings.theme.wrappedValue == theme
                        ) {
                            settings.theme.wrappedValue = theme
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }
}

/// A single theme selection button with color preview.
struct ThemeButton: View {
    let theme: ReaderSettings.ReaderTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: theme.nsBackgroundColor))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("A")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(nsColor: theme.nsTextColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
