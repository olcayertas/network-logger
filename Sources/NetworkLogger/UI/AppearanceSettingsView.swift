#if canImport(SwiftUI)
import Perception
import SwiftUI

/// Quick-settings sheet wired to `AppearanceSettings`.
struct AppearanceSettingsView: View {
    @Perception.Bindable var settings: AppearanceSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                Form {
                    Section("Theme") {
                        Picker("Color scheme", selection: $settings.colorScheme) {
                            Text("System").tag(AppearanceSettings.ColorSchemeOverride.system)
                            Text("Light").tag(AppearanceSettings.ColorSchemeOverride.light)
                            Text("Dark").tag(AppearanceSettings.ColorSchemeOverride.dark)
                        }
                        .pickerStyle(.segmented)

                        Picker("Accent", selection: $settings.accent) {
                            ForEach(AppearanceSettings.AccentTint.allCases, id: \.self) { tint in
                                accentRow(for: tint).tag(tint)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Body font size")
                                Spacer()
                                Text("\(Int(settings.bodyFontSize)) pt")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: $settings.bodyFontSize,
                                in: AppearanceSettings.minFontSize...AppearanceSettings.maxFontSize,
                                step: 1
                            )
                            sampleText
                        }
                    } header: {
                        Text("Body view")
                    } footer: {
                        Text("Applied to the request and response body screens.")
                    }

                    Section {
                        Button(role: .destructive) {
                            settings.resetToDefaults()
                        } label: {
                            Text("Reset to defaults")
                        }
                    }
                }
                .navigationTitle("Appearance")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func accentRow(for tint: AppearanceSettings.AccentTint) -> some View {
        HStack {
            Circle()
                .fill(tint.color)
                .frame(width: 16, height: 16)
            Text(tint.rawValue.capitalized)
        }
    }

    private var sampleText: some View {
        Text(#"{ "id": 42, "name": "preview" }"#)
            .font(.system(size: settings.bodyFontSize, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
#endif
