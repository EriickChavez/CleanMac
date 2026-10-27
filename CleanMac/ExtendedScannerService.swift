//
//  ExtendedScannerService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

final class ExtendedScannerService: Sendable {
    static let shared = ExtendedScannerService()
    
    struct ScanProgress: Sendable {
        let currentPath: String
        let count: Int
    }
    
    // Carpetas extra que SÍ son basura, no apps
    private var extraPaths: [String] {
        let home = ScannerService.realHomeDirectory.path
        return [
            "\(home)/Desktop",
            "\(home)/Movies",
            "\(home)/Library/Logs",
            "\(home)/Library/Application Support/CrashReporter",
        ]
    }
    
    func scanExtended() throws -> [FileItem] {
        var all: [FileItem] = []
        let fm = FileManager.default
        
        for path in extraPaths {
            guard fm.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .isRegularFileKey], options: [.skipsPackageDescendants]) else { continue }
            
            for case let fileURL as URL in enumerator {
                guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      vals.isRegularFile == true,
                      let size = vals.fileSize else { continue }
                
                // Solo archivos >20MB para no llenar de basura pequeña
                if size < 20 * 1024 * 1024 { continue }
                
                let access = (try? fileURL.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate ?? .distantPast
                all.append(FileItem(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    sizeMB: Double(size) / 1024.0 / 1024.0,
                    lastAccess: access
                ))
            }
        }
        return all.sorted { $0.sizeMB > $1.sizeMB }
    }
    
    // Para pestañas inteligentes
    func largeFiles(from files: [FileItem]) -> [FileItem] {
        files.filter { $0.sizeMB > 500 }.sorted { $0.sizeMB > $1.sizeMB }.prefix(50).map { $0 }
    }
    
    func oldFiles(from files: [FileItem]) -> [FileItem] {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        return files.filter { $0.lastAccess < ninetyDaysAgo }.sorted { $0.lastAccess < $1.lastAccess }.prefix(50).map { $0 }
    }
    
    func installers(from files: [FileItem]) -> [FileItem] {
        let installerExts = ["dmg","pkg","zip","rar","tar","gz","iso"]
        return files.filter { installerExts.contains(($0.name as NSString).pathExtension.lowercased()) }.sorted { $0.sizeMB > $1.sizeMB }
    }
}
