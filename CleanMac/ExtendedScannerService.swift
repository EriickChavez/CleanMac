//
//  ExtendedScannerService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

final class ExtendedScannerService {
    static let shared = ExtendedScannerService()
    private let fm = FileManager.default
    
    private let forbiddenFolders = Set([
        "node_modules", ".git", "Pods", "DerivedData", ".build",
        "build", ".Trash", ".cache", "Carthage", ".pub-cache",
        ".gradle", ".cocoapods", "vendor", ".venv", "__pycache__"
    ])
    
    private init() {}
    
    func scanExtended() throws -> [FileItem] {
        var all: [FileItem] = []
        let home = ScannerService.realHomeDirectory
        let folders = ["Desktop", "Movies", "Documents"]
        
        for folder in folders {
            let folderURL = home.appendingPathComponent(folder)
            guard fm.fileExists(atPath: folderURL.path) else { continue }
            
            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            var counted = 0
            
            for case let fileURL as URL in enumerator {
                if all.count > 1500 { break }
                counted += 1
                if counted > 2000 { break }
                
                if let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   values.isDirectory == true {
                    if forbiddenFolders.contains(fileURL.lastPathComponent) {
                        enumerator.skipDescendants()
                        continue
                    }
                }
                
                guard let v = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey, .isDirectoryKey]),
                      v.isDirectory == false,
                      let size = v.fileSize else { continue }
                
                let mb = Double(size) / (1024 * 1024)
                if mb < 5 { continue }
                
                all.append(FileItem(name: fileURL.lastPathComponent, path: fileURL.path, sizeMB: mb, lastAccess: v.contentAccessDate ?? .distantPast))
            }
        }
        
        return all.sorted { $0.sizeMB > $1.sizeMB }
    }
}
