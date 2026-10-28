//
//  ScannerService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

final class ScannerService {
    static let shared = ScannerService()
    static var realHomeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
    private let fm = FileManager.default
    private init() {}
    
    func scanDownloads() throws -> [FileItem] {
        let url = Self.realHomeDirectory.appendingPathComponent("Downloads")
        
        guard fm.fileExists(atPath: url.path) else {
            print("[ScannerService] Downloads no existe")
            return []
        }
        
        guard let fileURLs = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("[ScannerService] No se pudo leer Downloads")
            return []
        }
        
        var result: [FileItem] = []
        
        for fileURL in fileURLs {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey, .isDirectoryKey]) else { continue }
            guard values.isDirectory == false else { continue }
            guard let fileSize = values.fileSize else { continue }
            
            let sizeMB = Double(fileSize) / (1024 * 1024)
            if sizeMB < 1 { continue }
            
            let item = FileItem(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                sizeMB: sizeMB,
                lastAccess: values.contentAccessDate ?? Date()
            )
            result.append(item)
        }
        
        return result.sorted { $0.sizeMB > $1.sizeMB }
    }
}
