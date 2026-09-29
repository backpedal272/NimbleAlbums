import Foundation

enum FileNaming {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func datePrefix(for date: Date?) -> String {
        guard let date else { return "unknown-date" }
        return dateFormatter.string(from: date)
    }

    /// Makes a name safe for the filesystem: strips path separators, leading dots,
    /// surrounding whitespace, and truncates unreasonably long names.
    static func sanitize(_ name: String) -> String {
        var result = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix(".") { result.removeFirst() }
        if result.count > 100 { result = String(result.prefix(100)) }
        return result.isEmpty ? "Untitled" : result
    }

    static func splitExtension(_ name: String) -> (stem: String, ext: String) {
        let url = URL(fileURLWithPath: name)
        let ext = url.pathExtension
        guard !ext.isEmpty else { return (name, "") }
        return (String(name.dropLast(ext.count + 1)), ext)
    }

    /// Returns `proposed`, or a "name (2).ext" variant that is unique within `used`
    /// (case-insensitive). Inserts the final choice into `used`.
    static func uniqueName(_ proposed: String, used: inout Set<String>) -> String {
        var name = proposed
        var n = 2
        while used.contains(name.lowercased()) {
            let (stem, ext) = splitExtension(proposed)
            name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            n += 1
        }
        used.insert(name.lowercased())
        return name
    }
}
