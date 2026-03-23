import SwiftUI

struct ToolsView: View {
    @ObservedObject var viewModel: ToolsViewModel
    @FocusState private var isTargetFieldFocused: Bool
    @FocusState private var isCustomPortsFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionCard(title: "Target", subtitle: "Run quick diagnostics against a host or domain") {
                        TextField("IP or host", text: $viewModel.target)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.done)
                            .focused($isTargetFieldFocused)
                            .onSubmit { isTargetFieldFocused = false }
                            .padding(12)
                            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    SectionCard(title: "Toolbox") {
                        Picker("Tool", selection: $viewModel.selectedTool) {
                            ForEach(ToolsViewModel.Tool.allCases) { tool in
                                Text(tool.rawValue).tag(tool)
                            }
                        }
                        .pickerStyle(.segmented)

                        if viewModel.selectedTool == .portScan {
                            Picker("Port Scan Mode", selection: $viewModel.portScanMode) {
                                ForEach(ToolsViewModel.PortScanMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if viewModel.portScanMode == .custom {
                                TextField("Ports or ranges: 22,80,443,8000-8100", text: $viewModel.customPortsInput)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.numbersAndPunctuation)
                                    .focused($isCustomPortsFocused)
                                    .padding(12)
                                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text("Use commas and ranges, e.g. 22,80,443,8000-8100")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Button(viewModel.isRunning ? "Running…" : "Start") {
                            dismissKeyboards()
                            Task { await viewModel.run() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRunning || viewModel.target.isEmpty)

                        if !viewModel.statusText.isEmpty {
                            Text(viewModel.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    resultSection
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(DragGesture().onChanged { _ in dismissKeyboards() })
            .onTapGesture { dismissKeyboards() }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tools")
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.selectedTool {
        case .ping:
            SectionCard(title: "Ping Result") {
                if let result = viewModel.pingResult {
                    InfoRow(title: "Host", value: result.host)
                    InfoRow(title: "Status", value: result.success ? "Reachable" : "Failed")
                    InfoRow(title: "Latency", value: result.latencyMs.map { "\($0) ms" } ?? "N/A")
                    InfoRow(title: "Message", value: result.message)
                } else {
                    Text("No result yet").foregroundStyle(.secondary)
                }
            }
        case .dns:
            SectionCard(title: "DNS Result") {
                if let result = viewModel.dnsResult {
                    InfoRow(title: "Host", value: result.host)
                    InfoRow(title: "Addresses", value: result.addresses.isEmpty ? "No records found" : result.addresses.joined(separator: ", "))
                } else {
                    Text("No result yet").foregroundStyle(.secondary)
                }
            }
        case .whois:
            SectionCard(title: "WHOIS / RDAP") {
                if let result = viewModel.whoisResult {
                    Text(result.rawText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text("No result yet").foregroundStyle(.secondary)
                }
            }
        case .portScan:
            SectionCard(title: "Open Ports") {
                if viewModel.visiblePortResults.isEmpty {
                    Text(viewModel.isRunning ? "Scanning…" : "No open ports yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.visiblePortResults) { result in
                        InfoRow(title: "Port \(result.port)", value: "Open")
                    }
                }
            }
        }
    }

    private func dismissKeyboards() {
        isTargetFieldFocused = false
        isCustomPortsFocused = false
        hideKeyboard()
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
