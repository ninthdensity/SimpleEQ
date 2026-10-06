import AppKit
import CoreAudio
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("simpleEQ.appStyle") private var styleRaw: String = AppStyle.glass.rawValue

    @State private var showingSavePreset = false
    @State private var newPresetName = ""

    var appDelegate: AppDelegate?
    var showsOpenWindowButton: Bool = false

    private var appStyle: AppStyle { AppStyle(rawValue: styleRaw) ?? .glass }
    private var theme: ThemePalette { ThemePalette.palette(for: appStyle) }

    private var styleBinding: Binding<AppStyle> {
        Binding(
            get: { AppStyle(rawValue: styleRaw) ?? .glass },
            set: { styleRaw = $0.rawValue }
        )
    }

    private var isRunning: Bool { model.engine.state == .running }

    private static let blackHoleInstallCommand = "brew install blackhole-2ch && sudo killall coreaudiod"

    var body: some View {
        ZStack {
            AppCanvas()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    devicePanel
                    eqPanel
                    footerPanel
                }
                .padding(18)
            }
        }
        .frame(minWidth: 540, idealWidth: 580, minHeight: 420)
        .appStyle(appStyle)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: styleRaw)
        .onAppear {
            guard let appDelegate else { return }
            appDelegate.showMainWindow = {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            styleMainWindow()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: theme.markGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.panelStroke, lineWidth: 1)
                    }
                    .shadow(color: theme.panelShadow, radius: 8, y: 4)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.98, green: 0.95, blue: 0.92))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("SimpleEQ")
                    .font(.system(size: appStyle == .website ? 22 : 20, weight: .bold, design: .rounded))
                    .tracking(appStyle == .website ? -0.6 : -0.4)
                    .foregroundStyle(theme.textPrimary)
                Text(appStyle == .website ? "Satisfying system sound" : "System equalizer")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 8)

            StylePicker(style: styleBinding)

            StatusChip(text: model.engine.statusMessage, live: isRunning)

            HStack(spacing: 8) {
                Text(model.eqEnabled ? "EQ On" : "Bypass")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.eqEnabled ? theme.textPrimary : theme.textSecondary)
                Toggle("", isOn: Binding(
                    get: { model.eqEnabled },
                    set: { model.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(theme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.elevatedFill, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(theme.panelStroke, lineWidth: 1)
            }
        }
    }

    private var devicePanel: some View {
        StylePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(title: "Routing")
                    Spacer()
                    Button {
                        model.refreshDevices()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                            .padding(7)
                            .background(theme.elevatedFill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Refresh devices")
                }

                deviceRow(
                    tint: Theme.bandColor(at: 7),
                    title: "Input",
                    subtitle: "Loopback",
                    selection: $model.selectedInputID,
                    devices: model.inputs
                )

                deviceRow(
                    tint: Theme.bandColor(at: 5),
                    title: "Output",
                    subtitle: "Speakers",
                    selection: $model.selectedOutputID,
                    devices: model.outputs
                )

                Divider().overlay(theme.panelStroke.opacity(0.6))

                Toggle(isOn: $model.claimSystemOutput) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claim system output")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                        Text("Route all apps through the loopback while running")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .tint(theme.accent)

                if model.inputs.contains(where: \.isSystemLoopback) == false {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(theme.accentWarm)
                                .font(.system(size: 12))
                            Text("No BlackHole found. Paste this into Terminal, then click Refresh.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        CopyableCommand(command: Self.blackHoleInstallCommand)
                    }
                    .padding(10)
                    .background(theme.accentWarm.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                }
            }
        }
    }

    private func deviceRow(
        tint: Color,
        title: String,
        subtitle: String,
        selection: Binding<AudioDeviceID?>,
        devices: [AudioDeviceInfo]
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .shadow(color: tint.opacity(0.45), radius: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(width: 64, alignment: .leading)

            Menu {
                Button("None") { selection.wrappedValue = nil }
                ForEach(devices) { d in
                    Button {
                        selection.wrappedValue = d.id
                    } label: {
                        HStack {
                            if d.isSystemLoopback {
                                Image(systemName: "circle.fill")
                            }
                            Text(d.name)
                            if selection.wrappedValue == d.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(deviceName(selection.wrappedValue, in: devices) ?? "Select…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(theme.elevatedFill, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .strokeBorder(theme.panelStroke, lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func deviceName(_ id: AudioDeviceID?, in devices: [AudioDeviceInfo]) -> String? {
        guard let id else { return nil }
        return devices.first(where: { $0.id == id })?.name
    }

    private var presetMenu: some View {
        Menu {
            ForEach(model.presets) { preset in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        model.applyPreset(preset)
                    }
                } label: {
                    if model.currentPresetName == preset.name {
                        Label(preset.name, systemImage: "checkmark")
                    } else {
                        Text(preset.name)
                    }
                }
            }
            if !model.presets.isEmpty {
                Divider()
            }
            Button("Save Preset…") {
                newPresetName = model.currentPresetName ?? ""
                showingSavePreset = true
            }
            if !model.presets.isEmpty {
                Menu("Delete") {
                    ForEach(model.presets) { preset in
                        Button(preset.name, role: .destructive) { model.deletePreset(preset) }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Text(model.currentPresetName ?? "Presets")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.elevatedFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.panelStroke, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .alert("Save Preset", isPresented: $showingSavePreset) {
            TextField("Name", text: $newPresetName)
            Button("Save") { model.savePreset(named: newPresetName) }
                .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves the band count, every slider, and the preamp. Using an existing name replaces it.")
        }
    }

    private var eqPanel: some View {
        StylePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    SectionLabel(title: "Equalizer")

                    HStack(spacing: 4) {
                        ForEach(Engine.BandCount.allCases) { count in
                            let selected = model.bandCount == count
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    model.applyBandCount(count)
                                }
                            } label: {
                                Text(count.rawValue)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(selected ? theme.primaryButtonText : theme.textSecondary)
                                    .frame(width: 36, height: 28)
                                    .background {
                                        if selected {
                                            Capsule(style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [theme.primaryButtonTop, theme.primaryButtonBottom],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(theme.elevatedFill, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(theme.panelStroke, lineWidth: 1)
                    }

                    Spacer()

                    presetMenu

                    PillButton(title: "Flat", icon: "minus.slash.plus", kind: .secondary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            model.flat()
                        }
                    }
                }

                HStack(spacing: 12) {
                    Text("Preamp")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 52, alignment: .leading)

                    GeometryReader { geo in
                        let t = CGFloat((model.globalGain + 24) / 36)
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.trackFill)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [theme.accentWarm.opacity(0.55), theme.accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * t))
                        }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = min(max(0, value.location.x / geo.size.width), 1)
                            model.setGlobalGain(Float(x * 36 - 24))
                        }
                )
                    }
                    .frame(height: 8)

                    Text(String(format: "%+.0f dB", model.globalGain))
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 52, alignment: .trailing)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(model.frequencies.enumerated()), id: \.offset) { index, hz in
                        BandFader(
                            label: Equalizer.label(for: hz),
                            color: Theme.bandColor(at: index),
                            value: Binding(
                                get: { Double(model.gains.indices.contains(index) ? model.gains[index] : 0) },
                                set: { model.setGain(Float($0), at: index) }
                            )
                        )
                    }
                }
                .frame(height: 200)
                .opacity(model.eqEnabled ? 1 : 0.35)
                .animation(.easeOut(duration: 0.2), value: model.eqEnabled)
            }
        }
    }

    private var footerPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = model.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.danger)
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                        .strokeBorder(theme.danger.opacity(0.3), lineWidth: 1)
                }
            }

            HStack(spacing: 10) {
                PillButton(
                    title: isRunning ? "Stop" : "Start",
                    icon: isRunning ? "stop.fill" : "play.fill",
                    kind: .primary,
                    isDisabled: !isRunning && (model.selectedInputID == nil || model.selectedOutputID == nil)
                ) {
                    model.toggleRunning()
                }

                if showsOpenWindowButton {
                    PillButton(title: "Window", icon: "macwindow", kind: .secondary) {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }

                Spacer()

                PillButton(title: "Quit", kind: .ghost) {
                    model.stop()
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

private struct CopyableCommand: View {
    let command: String
    @Environment(\.theme) private var theme
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.elevatedFill, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Copy the install command")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.trackFill, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .strokeBorder(theme.panelStroke, lineWidth: 1)
        }
    }
}

private struct BandFader: View {
    let label: String
    let color: Color
    @Binding var value: Double
    @Environment(\.theme) private var theme

    private let range: ClosedRange<Double> = -12...12
    private let trackHeight: CGFloat = 140

    var body: some View {
        VStack(spacing: 8) {
            Text(String(format: "%+.0f", value))
                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(abs(value) < 0.25 ? theme.textTertiary : color)
                .frame(height: 14)

            GeometryReader { geo in
                let h = geo.size.height
                let t = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let y = (1 - t) * h

                ZStack(alignment: .top) {
                    Capsule(style: .continuous)
                        .fill(theme.trackFill)
                        .frame(width: 6)
                        .frame(maxHeight: .infinity)
                        .frame(maxWidth: .infinity)

                    let mid = h / 2
                    let fillTop = min(y, mid)
                    let fillH = abs(y - mid)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.85)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 6, height: max(fillH, 2))
                        .offset(y: fillTop)
                        .frame(maxWidth: .infinity, alignment: .top)

                    Circle()
                        .fill(theme.primaryButtonTop.opacity(appStyleIsWebsite ? 1 : 0.95))
                        .frame(width: 14, height: 14)
                        .shadow(color: color.opacity(0.5), radius: 5)
                        .overlay {
                            Circle().strokeBorder(color.opacity(0.55), lineWidth: 1.5)
                        }
                        .offset(y: y - 7)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let clamped = min(max(0, drag.location.y), h)
                            let nt = 1 - clamped / h
                            let raw = range.lowerBound + Double(nt) * (range.upperBound - range.lowerBound)
                            value = (raw * 2).rounded() / 2
                        }
                )
            }
            .frame(height: trackHeight)

            VStack(spacing: 3) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.55), radius: 3)
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @Environment(\.appStyle) private var appStyle
    private var appStyleIsWebsite: Bool { appStyle == .website }
}
