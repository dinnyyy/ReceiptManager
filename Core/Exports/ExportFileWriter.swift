import Foundation

/// Writes generated exports to a scratch directory for the share sheet to
/// read from. Spec 12.5: "Export generation is a user-initiated operation;
/// do not retain generated copies on the backend by default in V1" - these
/// files are local-only and never uploaded anywhere.
enum ExportFileWriter {
    static func writePDF(_ data: Data, packType: ProofPackType, date: Date = Date()) -> URL? {
        write(data, filename: filename(packType: packType, ext: "pdf", date: date))
    }

    static func writeCSV(_ csv: String, packType: ProofPackType, date: Date = Date()) -> URL? {
        guard let data = csv.data(using: .utf8) else { return nil }
        return write(data, filename: filename(packType: packType, ext: "csv", date: date))
    }

    private static func write(_ data: Data, filename: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // Spec 12.5 filename example: Tax_Proof_Pack_FY2026-27_2026-08-17.pdf
    private static func filename(packType: ProofPackType, ext: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let namePart = packType.title.replacingOccurrences(of: " ", with: "_")
        return "\(namePart)_\(formatter.string(from: date)).\(ext)"
    }
}
