//
//  Models.swift.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

// MARK: - FileItem

struct FileItem: Identifiable, Hashable, Sendable {
    
    var id: String { path }
    
    let name: String
    let path: String
    let sizeMB: Double
    let lastAccess: Date
    var isHidden: Bool = false
    
    // Init principal
    init(name: String, path: String, sizeMB: Double, lastAccess: Date, isHidden: Bool = false) {
        self.name = name
        self.path = path
        self.sizeMB = sizeMB
        self.lastAccess = lastAccess
        self.isHidden = isHidden
    }
    
    // Compatibilidad
    init(name: String, path: String, sizeMB: Double, lastAccess: Date?) {
        self.name = name
        self.path = path
        self.sizeMB = sizeMB
        self.lastAccess = lastAccess ?? Date()
        self.isHidden = false
    }
    
    init(name: String, path: String, sizeMB: Double, lastAccess: Date, isHidden: Bool, typeDescription: String) {
        self.name = name
        self.path = path
        self.sizeMB = sizeMB
        self.lastAccess = lastAccess
        self.isHidden = isHidden
    }
    
    // MARK: - Computed
    
    var typeDescription: String {
        (name as NSString).pathExtension.uppercased()
    }
    
    var sizeText: String {
        Self.formatMB(sizeMB)
    }
    
    var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }
    
    var dateText: String {
        Self.formatDate(lastAccess)
    }
    
    // MARK: - Helpers centralizados
    
    static func formatMB(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.path == rhs.path
    }
}

// MARK: - Risk

enum RiskLevel: String, Sendable, CaseIterable {
    case safe = "Seguro"
    case caution = "Precaución"
    case risky = "Riesgoso"
}

struct FileAnalysis: Sendable {
    let risk: RiskLevel
    let reason: String
    let shouldDelete: Bool
    
    init(risk: RiskLevel, reason: String, shouldDelete: Bool) {
        self.risk = risk
        self.reason = reason
        self.shouldDelete = shouldDelete
    }
    
    init(risk: RiskLevel, explanation_es: String, recommendation: String) {
        self.risk = risk
        self.reason = explanation_es
        self.shouldDelete = risk == .safe
    }
}

struct FileAnalysisResult: Identifiable, Sendable {
    var id: String { path }
    let path: String
    let name: String
    let analysis: FileAnalysis
    var usedLLM: Bool = false
}

// MARK: - Pro Detection

struct ProDetectionResult: Sendable {
    let detectedTools: [String]
    
    var isProUser: Bool { !detectedTools.isEmpty }
    
    var modeName: String {
        if detectedTools.isEmpty {
            return "Modo Simple"
        } else {
            return "Modo Pro (\(detectedTools.joined(separator: ", ")))"
        }
    }
    
    init(detectedTools: [String]) {
        self.detectedTools = detectedTools
    }
    
    init(isProUser: Bool, modeName: String, detectedTools: [String]) {
        self.detectedTools = detectedTools
    }
    
    static func detect() throws -> ProDetectionResult {
        var tools: [String] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        
        let checks: [(String, String)] = [
            ("/Applications/Xcode.app", "Xcode"),
            ("\(home)/Library/Developer/Xcode", "Xcode"),
            ("/Applications/Android Studio.app", "Android Studio"),
            ("\(home)/.gradle", "Gradle"),
            ("/opt/homebrew/bin/node", "Node"),
            ("\(home)/.npm", "NPM"),
            ("/Applications/Docker.app", "Docker"),
            ("\(home)/.docker", "Docker"),
            ("\(home)/.cocoapods", "CocoaPods"),
            ("/usr/local/bin/flutter", "Flutter"),
            ("/opt/homebrew/bin/flutter", "Flutter"),
        ]
        
        for (path, name) in checks {
            if fm.fileExists(atPath: path) {
                tools.append(name)
            }
        }
        
        let unique = Array(Set(tools))
        return ProDetectionResult(detectedTools: unique)
    }
}

// MARK: - Deep Clean

enum DeepCleanCategory: String, CaseIterable, Sendable {
    case xcode = "Xcode"
    case docker = "Docker"
    case caches = "Caches"
    case logs = "Logs"
    case simulator = "Simulador"
    case gradle = "Gradle"
    case node = "Node"
    case other = "Otro"
}

struct DeepCleanItem: Identifiable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let sizeMB: Double
    let category: DeepCleanCategory
    let explanation: String
    
    init(name: String, path: String, sizeMB: Double, category: DeepCleanCategory, explanation: String) {
        self.name = name
        self.path = path
        self.sizeMB = sizeMB
        self.category = category
        self.explanation = explanation
    }
    
    init(name: String, path: String, size: Double, category: DeepCleanCategory, explanation: String) {
        self.name = name
        self.path = path
        self.sizeMB = size
        self.category = category
        self.explanation = explanation
    }
}

// MARK: - App Caches

struct AppCacheInfo: Identifiable, Sendable {
    var id: String { path }
    let appName: String
    let path: String
    let sizeMB: Double
    let bundleId: String?
}

// MARK: - Duplicates

struct DuplicateGroup: Identifiable, Sendable {
    var id: String {
        files.first?.path ?? UUID().uuidString
    }
    let files: [FileItem]
    
    var totalSavingsMB: Double {
        guard files.count > 1 else { return 0 }
        return files.dropFirst().reduce(0) { $0 + $1.sizeMB }
    }
    
    var savingsText: String {
        FileItem.formatMB(totalSavingsMB)
    }
}
