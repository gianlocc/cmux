import SwiftUI

/// **Sleepy Mode** section — the keep-awake screensaver/lock: appearance,
/// scene toggles, the Touch ID lock toggle, and preview/start actions.
@MainActor
public struct SleepyModeSection: View {
    @Bindable private var store: SleepyModeSettingsStore
    private let hostActions: SettingsHostActions

    /// `store` defaults to the app-wide shared instance because the Sleepy Mode
    /// scene (in the app target) and this section read one source of truth; pass
    /// an isolated store for previews/tests.
    public init(hostActions: SettingsHostActions, store: SleepyModeSettingsStore) {
        self.hostActions = hostActions
        self._store = Bindable(store)
    }

    /// The Sleepy Mode settings section view.
    public var body: some View {
        Group {
            SettingsSectionHeader(String(localized: "settings.section.sleepyMode", defaultValue: "Sleepy Mode"), section: .sleepyMode)

            SettingsCard {
                SettingsCardRow(
                    configurationReview: .settingsOnly,
                    String(localized: "sleepyMode.settings.theme", defaultValue: "Theme")
                ) {
                    Picker("", selection: $store.theme) {
                        Text(String(localized: "sleepyMode.theme.cmux", defaultValue: "cmux")).tag(SleepyTheme.cmux)
                        Text(String(localized: "sleepyMode.theme.blossom", defaultValue: "Blossom")).tag(SleepyTheme.blossom)
                        Text(String(localized: "sleepyMode.theme.mint", defaultValue: "Mint")).tag(SleepyTheme.mint)
                        Text(String(localized: "sleepyMode.theme.mono", defaultValue: "Mono")).tag(SleepyTheme.mono)
                        Text(String(localized: "sleepyMode.theme.custom", defaultValue: "Custom")).tag(SleepyTheme.custom)
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.small)
                }
                SettingsCardDivider()
                SettingsCardRow(
                    configurationReview: .settingsOnly,
                    String(localized: "sleepyMode.settings.mascot", defaultValue: "Mascot")
                ) {
                    Picker("", selection: $store.mascot) {
                        Text(String(localized: "sleepyMode.mascot.cmux", defaultValue: "cmux mascot")).tag(SleepyMascot.cmux)
                        Text(String(localized: "sleepyMode.mascot.cat", defaultValue: "Cat")).tag(SleepyMascot.cat)
                        Text(String(localized: "sleepyMode.mascot.ghost", defaultValue: "Ghost")).tag(SleepyMascot.ghost)
                        Text(String(localized: "sleepyMode.mascot.bunny", defaultValue: "Bunny")).tag(SleepyMascot.bunny)
                        Text(String(localized: "sleepyMode.mascot.logoFace", defaultValue: "Logo face")).tag(SleepyMascot.logoFace)
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.small)
                }
                SettingsCardDivider()
                SettingsCardRow(
                    configurationReview: .settingsOnly,
                    String(localized: "sleepyMode.settings.glow", defaultValue: "Background glow")
                ) {
                    Picker("", selection: $store.glow) {
                        Text(String(localized: "sleepyMode.glow.black", defaultValue: "Black")).tag(SleepyGlow.black)
                        Text(String(localized: "sleepyMode.glow.midnight", defaultValue: "Midnight")).tag(SleepyGlow.midnight)
                        Text(String(localized: "sleepyMode.glow.cmux", defaultValue: "cmux")).tag(SleepyGlow.cmux)
                        Text(String(localized: "sleepyMode.glow.aurora", defaultValue: "Aurora")).tag(SleepyGlow.aurora)
                        Text(String(localized: "sleepyMode.glow.sunset", defaultValue: "Sunset")).tag(SleepyGlow.sunset)
                        Text(String(localized: "sleepyMode.glow.ocean", defaultValue: "Ocean")).tag(SleepyGlow.ocean)
                        Text(String(localized: "sleepyMode.glow.custom", defaultValue: "Custom")).tag(SleepyGlow.custom)
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.small)
                }
            }

            if store.theme == .custom || store.glow == .custom {
                SettingsCard {
                    if store.theme == .custom {
                        colorRow(String(localized: "sleepyMode.color.face", defaultValue: "Face"), $store.customFace)
                        SettingsCardDivider()
                        colorRow(String(localized: "sleepyMode.color.cap", defaultValue: "Nightcap"), $store.customCap)
                        SettingsCardDivider()
                        colorRow(String(localized: "sleepyMode.color.blush", defaultValue: "Blush"), $store.customBlush)
                        SettingsCardDivider()
                        colorRow(String(localized: "sleepyMode.color.eyes", defaultValue: "Eyes"), $store.customInk)
                        SettingsCardDivider()
                        colorRow(String(localized: "sleepyMode.color.logo", defaultValue: "Logo"), $store.customLogo)
                        if store.glow == .custom { SettingsCardDivider() }
                    }
                    if store.glow == .custom {
                        colorRow(String(localized: "sleepyMode.color.background", defaultValue: "Background"), $store.customBackground)
                    }
                }
            }

            SettingsCard {
                toggleRow(String(localized: "sleepyMode.settings.clock", defaultValue: "Clock & date"), $store.showClock)
                SettingsCardDivider()
                toggleRow(String(localized: "sleepyMode.settings.status", defaultValue: "Battery & Wi-Fi"), $store.showStatus)
                SettingsCardDivider()
                SettingsCardRow(
                    configurationReview: .settingsOnly,
                    String(localized: "sleepyMode.settings.pets", defaultValue: "Agent pets"),
                    subtitle: String(localized: "sleepyMode.settings.pets.subtitle", defaultValue: "Walks one cute pet for every Claude, Codex, and OpenCode agent you have running.")
                ) {
                    Toggle("", isOn: $store.showPets).labelsHidden().controlSize(.small)
                }
                SettingsCardDivider()
                toggleRow(String(localized: "sleepyMode.settings.moon", defaultValue: "Moon"), $store.showMoon)
                SettingsCardDivider()
                toggleRow(String(localized: "sleepyMode.settings.stars", defaultValue: "Stars"), $store.showStars)
                SettingsCardDivider()
                toggleRow(String(localized: "sleepyMode.settings.zs", defaultValue: "Floating z z z"), $store.showZs)
            }

            SettingsCard {
                SettingsCardRow(
                    configurationReview: .settingsOnly,
                    String(localized: "sleepyMode.settings.requireAuth", defaultValue: "Require Touch ID to exit"),
                    subtitle: store.requireAuth
                        ? String(localized: "sleepyMode.settings.requireAuth.on", defaultValue: "Any key or click asks for Touch ID, with your account password as the fallback. Cmd-Q and Cmd-W are swallowed too, but Force Quit still closes cmux.")
                        : String(localized: "sleepyMode.settings.requireAuth.off", defaultValue: "Casual screensaver. Any key or click wakes it.")
                ) {
                    Toggle("", isOn: $store.requireAuth).labelsHidden().controlSize(.small)
                }
                SettingsCardDivider()
                SettingsCardRow(
                    configurationReview: .settingsOnly,
                    String(localized: "sleepyMode.settings.securityNote", defaultValue: "About security"),
                    subtitle: String(localized: "sleepyMode.settings.securityNote.subtitle", defaultValue: "Even with Touch ID required, Sleepy Mode is a deterrent rather than a real lock: cmux is an ordinary app, so force-quitting it or connecting remotely still reaches your desktop. For genuine security use the \u{201C}Lock Mac\u{201D} button in the scene, which engages the actual macOS login lock.")
                ) {
                    EmptyView()
                }
            }

            SettingsCard {
                SettingsCardRow(
                    String(localized: "sleepyMode.settings.previewRow", defaultValue: "Preview"),
                    subtitle: String(localized: "sleepyMode.settings.previewRow.subtitle", defaultValue: "Shows the scene full screen; any key or click exits, or asks for Touch ID when the lock above is on.")
                ) {
                    Button(String(localized: "sleepyMode.settings.preview", defaultValue: "Preview full screen")) {
                        hostActions.sleepyModePreview()
                    }
                    .controlSize(.small)
                }
                SettingsCardDivider()
                SettingsCardRow(
                    String(localized: "sleepyMode.settings.startRow", defaultValue: "Start Sleepy Mode now"),
                    subtitle: String(localized: "sleepyMode.settings.startRow.subtitle", defaultValue: "Engages Sleepy Mode using the settings above.")
                ) {
                    Button(String(localized: "sleepyMode.settings.start", defaultValue: "Start")) {
                        hostActions.sleepyModeStart()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        SettingsCardRow(configurationReview: .settingsOnly, title) {
            Toggle("", isOn: binding).labelsHidden().controlSize(.small)
        }
    }

    @ViewBuilder
    private func colorRow(_ title: String, _ hex: Binding<String>) -> some View {
        SettingsCardRow(configurationReview: .settingsOnly, title) {
            ColorPicker("", selection: Binding(
                get: { Color(sleepyHex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.sleepyHex }
            ))
            .labelsHidden()
        }
    }
}
