import SwiftUI
import PushPlatformSDK

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // Installation ID Section
                    GroupBox(label: Label("Installation", systemImage: "app.badge")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let installationID = viewModel.installationID {
                                HStack {
                                    Text("ID:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(installationID.uuidString)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)
                                }

                                Button(action: {
                                    UIPasteboard.general.string = installationID.uuidString
                                    viewModel.showCopiedAlert = true
                                }) {
                                    Label("Copy ID", systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                            } else {
                                Text("Initializing...")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Token Status Section
                    GroupBox(label: Label("Push Tokens", systemImage: "bell.badge")) {
                        VStack(spacing: 12) {
                            StatusRow(title: "APNs Token", status: viewModel.apnsTokenStatus)
                            Divider()
                            StatusRow(title: "VoIP Token", status: viewModel.voipTokenStatus)
                        }
                        .padding(.vertical, 4)
                    }

                    // User Management Section
                    GroupBox(label: Label("User Management", systemImage: "person")) {
                        VStack(spacing: 12) {
                            if viewModel.isLoggedIn {
                                HStack {
                                    Text("Logged in as:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(viewModel.userID ?? "")
                                        .font(.system(.body, design: .monospaced))
                                }

                                Button(action: viewModel.logout) {
                                    Label("Logout", systemImage: "arrow.right.square")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .disabled(viewModel.isLoading)
                            } else {
                                TextField("User ID", text: $viewModel.userIDInput)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                Button(action: viewModel.login) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                    } else {
                                        Label("Login", systemImage: "arrow.right.square")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.userIDInput.isEmpty || viewModel.isLoading)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Notifications Section
                    GroupBox(label: Label("Recent Notifications", systemImage: "tray")) {
                        if viewModel.notifications.isEmpty {
                            Text("No notifications yet")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(viewModel.notifications) { notification in
                                NotificationRow(notification: notification)
                                if notification.id != viewModel.notifications.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    // Calls Section
                    if !viewModel.calls.isEmpty {
                        GroupBox(label: Label("Recent Calls", systemImage: "phone")) {
                            ForEach(viewModel.calls) { call in
                                CallRow(call: call)
                                if call.id != viewModel.calls.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Push Platform")
            .alert("Copied!", isPresented: $viewModel.showCopiedAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let title: String
    let status: TokenStatus

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                Text(status.text)
                    .font(.caption)
            }
        }
    }
}

enum TokenStatus {
    case pending
    case registered
    case failed

    var text: String {
        switch self {
        case .pending: return "Pending"
        case .registered: return "Registered"
        case .failed: return "Failed"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .registered: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: NotificationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(notification.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let body = notification.body {
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let eventID = notification.eventID {
                Text("Event: \(eventID)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Call Row

struct CallRow: View {
    let call: CallItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "phone.fill")
                    .foregroundColor(.green)
                Text(call.callerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(call.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text("Call ID: \(call.callID)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fontDesign(.monospaced)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
