//
//  AppCacheService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
import AppKit

struct AppCacheInfo: Identifiable, Sendable, Equatable {
    let id = UUID(); let name: String; let bundleID: String?; let icon: NSImage?; let cachePaths: [String]; let totalSizeMB: Double; let isCLI: Bool
    var sizeText: String { totalSizeMB > 1024 ? String(format: "%.2f GB", totalSizeMB/1024) : String(format: "%.0f MB", totalSizeMB) }
    static func == (lhs: AppCacheInfo, rhs: AppCacheInfo) -> Bool { lhs.id == rhs.id }
}

final class AppCacheService: Sendable {
    static let shared = AppCacheService()
    func scanAllAppCaches() -> [AppCacheInfo] {
        var results: [AppCacheInfo] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for folder in ["/Applications", "\(home)/Applications"] {
            guard let apps = try? FileManager.default.contentsOfDirectory(atPath: folder) else { continue }
            for appName in apps where appName.hasSuffix(".app") {
                let full = "\(folder)/\(appName)"; let name = appName.replacingOccurrences(of: ".app", with: "")
                let bid = Bundle(path: full)?.bundleIdentifier; let icon = NSWorkspace.shared.icon(forFile: full)
                var caches = [String](); if let bid { caches.append("\(home)/Library/Caches/\(bid)") }
                caches.append("\(home)/Library/Caches/\(name)")
                let size = fastSize(paths: caches); if size > 10 {
                    results.append(AppCacheInfo(name: name, bundleID: bid, icon: icon, cachePaths: caches, totalSizeMB: size, isCLI: false))
                }
                if results.count > 30 { break }
            }
        }
        let cliTools = [("Node.js", ["\(home)/.npm", "\(home)/Library/Caches/node"]), ("Homebrew", ["\(home)/Library/Caches/Homebrew"]), ("Python", ["\(home)/Library/Caches/pip"])]
        for tool in cliTools {
            let size = fastSize(paths: tool.1); if size > 1 {
                let icon = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil)
                results.append(AppCacheInfo(name: tool.0, bundleID: nil, icon: icon, cachePaths: tool.1, totalSizeMB: size, isCLI: true))
            }
        }
        return results.sorted { $0.totalSizeMB > $1.totalSizeMB }
    }
    private func fastSize(paths: [String]) -> Double {
        var total: Double = 0
        for path in paths { guard FileManager.default.fileExists(atPath: path) else { continue }
            let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/du"); task.arguments = ["-sm", path]
            let pipe = Pipe(); task.standardOutput = pipe; task.standardError = Pipe(); try? task.run(); task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let out = String(data: data, encoding: .utf8), let mb = Double(out.components(separatedBy: "\t").first ?? "") { total += mb }
        }
        return total
    }
    func clearCache(for app: AppCacheInfo) throws { for p in app.cachePaths { try? FileManager.default.removeItem(atPath: p) } }
}
