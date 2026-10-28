//
//  DeepCleanService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
final class DeepCleanService {
    static let shared = DeepCleanService()
    private let fm = FileManager.default
    func scanDeepClean() -> [DeepCleanItem] {
        var items: [DeepCleanItem] = []; let home = ScannerService.realHomeDirectory.path
        let paths: [(String, DeepCleanCategory, String)] = [("\(home)/Library/Logs",.logs,"Logs del sistema - seguro borrar"),("\(home)/Library/Caches/com.apple.Safari",.caches,"Safari Cache")]
        for (p,c,d) in paths { guard fm.fileExists(atPath: p) else { continue }; let s = fastSize(path: p); if s<50 { continue }; items.append(DeepCleanItem(name: URL(fileURLWithPath: p).lastPathComponent, path: p, sizeMB: s, category: c, explanation: d)) }
        return items.sorted { $0.sizeMB > $1.sizeMB }
    }
    func delete(item: DeepCleanItem) throws { try fm.removeItem(atPath: item.path) }
    private func fastSize(path: String) -> Double { let url=URL(fileURLWithPath: path); guard let e=fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {return 0}; var t:UInt64=0; for case let f as URL in e { if let s=try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize { t+=UInt64(s) } }; return Double(t)/(1024*1024) }
}
