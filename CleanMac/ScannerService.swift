//
//  ScannerService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

final class ScannerService: Sendable {
    static let shared = ScannerService()
    static var realHomeDirectory: URL { FileManager.default.homeDirectoryForCurrentUser }
    
    func scanDownloads() throws -> [FileItem] {
        let downloads = Self.realHomeDirectory.appendingPathComponent("Downloads")
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: downloads, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey], options: .skipsHiddenFiles) else { return [] }
        
        return files.compactMap { url in
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }
            let size = (attrs[.size] as? UInt64 ?? 0)
            let date = attrs[.creationDate] as? Date ?? .distantPast
            return FileItem(name: url.lastPathComponent, path: url.path, sizeMB: Double(size)/1024/1024, lastAccess: date)
        }.sorted { $0.sizeMB > $1.sizeMB }
    }
    
    func scanHiddenCaches() -> [FileItem] {
        let home = Self.realHomeDirectory.path
        let paths = ["\(home)/Library/Caches", "\(home)/Library/Application Support"]
        var result: [FileItem] = []
        for base in paths {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: base) else { continue }
            for name in files {
                let full = "\(base)/\(name)"
                if let size = fastSizeMB(path: full), size > 100 {
                    result.append(FileItem(name: name, path: full, sizeMB: size, lastAccess: .distantPast, isHidden: true))
                }
            }
        }
        return result.sorted { $0.sizeMB > $1.sizeMB }
    }
    
    private func fastSizeMB(path: String) -> Double? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/du"); task.arguments = ["-sm", path]
        let pipe = Pipe(); task.standardOutput = pipe; task.standardError = Pipe()
        try? task.run(); task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8), let mb = Double(out.components(separatedBy: "\t").first ?? "") { return mb }
        return nil
    }
}
