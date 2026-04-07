import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LauncherStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                topBar
                presetSection
                projectList
                footer
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#0B0E13"),
                    Color(hex: "#111722"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .alert(
            "Project Launcher",
            isPresented: Binding(
                get: { store.alertMessage != nil },
                set: { newValue in
                    if !newValue {
                        store.alertMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                store.alertMessage = nil
            }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }

    private var topBar: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Project Launcher")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#F7F9FC"))

                        Text("Last launch \(store.lastLaunchDescription)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "#8E99AB"))
                    }
                    .frame(width: 190, alignment: .leading)

                    Spacer(minLength: 0)

                    Button(action: store.launchSelected) {
                        Text(store.launchButtonTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(width: 208)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#2E76FF"))
                    .disabled(store.selectedCount == 0)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fallback Open With")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "#8E99AB"))

                        Picker("Fallback Open With", selection: $store.defaultLaunchTarget) {
                            ForEach(LaunchTarget.defaultChoices) { target in
                                Text(target.displayName).tag(target)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 118)
                        .tint(Color(hex: "#EEF2FF"))
                    }
                    .frame(width: 136, alignment: .trailing)
                }

                Text(store.summaryText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "#A9B3C4"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var presetSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sets")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#EEF3FA"))

                        Text("Current Set updates live. Last Launch updates after you launch.")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "#7F8A9A"))
                    }

                    Spacer(minLength: 8)

                    Button("Reset Starter", action: store.resetToStarterList)
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#7B8798"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }

                HStack(spacing: 10) {
                    BuiltInSetCard(
                        title: "Current Set",
                        subtitle: store.currentSetSummary,
                        badge: "Live",
                        actionTitle: nil as String?,
                        action: nil as (() -> Void)?
                    )

                    BuiltInSetCard(
                        title: "Last Launch",
                        subtitle: store.lastLaunchSummary,
                        badge: store.hasLastLaunchPreset ? "Saved" : "Empty",
                        actionTitle: store.hasLastLaunchPreset ? "Load" : nil,
                        action: store.hasLastLaunchPreset ? { store.applyLastLaunchPreset() } : nil
                    )
                }

                HStack(spacing: 8) {
                    TextField("Preset name", text: $store.presetDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#121925"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )

                    Button("Save Current", action: store.saveCurrentPreset)
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#7B8798"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }

                if !store.presets.isEmpty {
                    Text("Saved Presets")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#7F8A9A"))

                    FlowLayout(spacing: 8) {
                        ForEach(store.presets) { preset in
                            HStack(spacing: 6) {
                                PresetChip(title: preset.name) {
                                    store.applyPreset(preset)
                                }

                                Button {
                                    store.deletePreset(preset)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#6B7688"))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($store.projects) { $project in
                ProjectCard(project: $project)
            }
        }
    }

    private var footer: some View {
        Text(store.statusMessage)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color(hex: "#7F8A9A"))
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
    }
}

private struct ProjectCard: View {
    @Binding var project: LaunchProject

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $project.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "#EFF3FA"))

                Text(project.path)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#7F8A9A"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Open With", selection: $project.launchTarget) {
                ForEach(LaunchTarget.allCases) { target in
                    Text(target.displayName).tag(target)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 162)
            .tint(Color(hex: "#DCE5F6"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#121925"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .opacity(project.isEnabled ? 1.0 : 0.58)
        .animation(.easeInOut(duration: 0.14), value: project.isEnabled)
    }
}

private struct PresetChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "#D6DEED"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(Color(hex: "#171F2C"))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct BuiltInSetCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#EEF3FA"))

                Spacer(minLength: 6)

                Text(badge)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "#B7C2D6"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#171F2C"))
                    .clipShape(Capsule())
            }

            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#7F8A9A"))
                .lineLimit(2)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(Color(hex: "#7B8798"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "#121925"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct PanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.sRGB, red: 15 / 255, green: 20 / 255, blue: 29 / 255, opacity: 0.94))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.06), lineWidth: 1)

            content
                .padding(14)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 700
        var cursor = CGPoint.zero
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > maxWidth, cursor.x > 0 {
                cursor.x = 0
                cursor.y += lineHeight + spacing
                lineHeight = 0
            }

            lineHeight = max(lineHeight, size.height)
            cursor.x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: cursor.y + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var cursor = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > bounds.maxX, cursor.x > bounds.minX {
                cursor.x = bounds.minX
                cursor.y += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: cursor,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            cursor.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        let value = Int(cleaned, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xff) / 255.0
        let green = Double((value >> 8) & 0xff) / 255.0
        let blue = Double(value & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
