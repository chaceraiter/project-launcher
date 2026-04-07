import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LauncherStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard
                actionRow
                projectList
                footer
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundGradient)
        .onReceive(store.$projects) { _ in
            store.projectChanged()
        }
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Project Launcher")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.22))

            Text("Bring back your working set after a restart. Choose which projects should launch, pick the assistant for each one, and optionally open the editor too.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.24, green: 0.32, blue: 0.34))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label("Last launch", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.29, green: 0.38, blue: 0.40))

                Text(store.lastLaunchDescription)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.34, green: 0.42, blue: 0.44))
            }

            FlowLayout(spacing: 10) {
                ForEach(store.summaryChips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.72))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.68), lineWidth: 1)
                        )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.97, blue: 0.95),
                    Color(red: 0.98, green: 0.94, blue: 0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 12)
    }

    private var actionRow: some View {
        HStack(spacing: 14) {
            Button(action: store.launchSelected) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text(store.launchButtonTitle)
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(minWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.13, green: 0.45, blue: 0.39))
            .disabled(store.selectedCount == 0)

            Button("Reset Defaults", action: store.resetDefaults)
                .buttonStyle(.bordered)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tint(Color(red: 0.23, green: 0.30, blue: 0.34))

            Spacer()
        }
    }

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach($store.projects) { $project in
                ProjectCard(project: $project)
            }
        }
    }

    private var footer: some View {
        Text(store.statusMessage)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.32, green: 0.40, blue: 0.42))
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.93, blue: 0.89),
                Color(red: 0.91, green: 0.95, blue: 0.96),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct ProjectCard: View {
    @Binding var project: LaunchProject

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Toggle("", isOn: $project.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(project.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.11, green: 0.20, blue: 0.22))

                    AssistantBadge(assistant: project.assistant)
                }

                Text(project.path)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.39, green: 0.46, blue: 0.48))

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assistant")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.42, green: 0.49, blue: 0.52))

                        Picker("Assistant", selection: $project.assistant) {
                            ForEach(AssistantKind.allCases) { assistant in
                                Text(assistant.displayName).tag(assistant)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Editor")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.42, green: 0.49, blue: 0.52))

                        Picker("Editor", selection: $project.editor) {
                            ForEach(EditorKind.allCases) { editor in
                                Text(editor.displayName).tag(editor)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color.white.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 10)
        .opacity(project.isEnabled ? 1.0 : 0.66)
        .animation(.easeInOut(duration: 0.16), value: project.isEnabled)
    }
}

private struct AssistantBadge: View {
    let assistant: AssistantKind

    var body: some View {
        Text(assistant.displayName)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(Color(hex: assistant.tintHex))
            .clipShape(Capsule())
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
        let maxWidth = proposal.width ?? 800
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
