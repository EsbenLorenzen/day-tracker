import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DayTrackerCore

/// Export everything as a .zip for analysis and backup; import a backup (D17).
struct DataSection: View {
    private struct ExportFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    @Environment(\.modelContext) private var context
    @State private var exportFile: ExportFile?
    @State private var isImporting = false
    @State private var alertMessage: String?

    var body: some View {
        Section {
            Button("Export all data", systemImage: "square.and.arrow.up") {
                do {
                    exportFile = ExportFile(url: try DataExport.writeArchive(from: context))
                } catch {
                    alertMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            Button("Import backup", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Export makes one .zip with CSV files for analysis and a full backup. Save it to Files or iCloud Drive, or email it to yourself. Importing a backup only adds what's missing; nothing is deleted or overwritten.")
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(url: file.url)
                .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.zip, .json]) { result in
            alertMessage = importBackup(result)
        }
        .alert("Data", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func importBackup(_ result: Result<URL, any Error>) -> String {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let backup = try Backup.decode(Data(contentsOf: url))
            let summary = DataImport.run(backup, into: context)
            CheckInStore.reconcile(in: context)
            Task { await NotificationScheduler.reschedule() }
            return summary.text
        } catch let error as BackupError {
            return message(for: error)
        } catch {
            return "Import failed: \(error.localizedDescription)"
        }
    }

    private func message(for error: BackupError) -> String {
        switch error {
        case .unsupportedVersion:
            "This backup was made by a newer version of DayTracker. Update the app and try again."
        case .missingBackupFile:
            "This .zip doesn't contain a backup.json."
        case .invalidArchive:
            "This file isn't a DayTracker export."
        case .compressedArchive:
            "This .zip was re-compressed. Open it in Files to unzip it, then import backup.json."
        }
    }
}

/// The system share sheet for one file.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
