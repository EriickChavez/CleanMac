//
//  ProfileService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

enum DevSubProfile: String, CaseIterable, Identifiable {
    case ios = "iOS"
    case android = "Android"
    case webNode = "Web/Node"
    case python = "Python"
    case flutter = "Flutter"
    case ruby = "Ruby/CocoaPods"
    case docker = "Docker"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .ios: return "applelogo"
        case .android: return "smartphone"
        case .webNode: return "globe"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .flutter: return "f.cursive"
        case .ruby: return "diamond.fill"
        case .docker: return "shippingbox.fill"
        }
    }
    
    var scanPaths: [(path: String, desc: String, category: DeepCleanCategory)] {
        let home = ScannerService.realHomeDirectory.path
        switch self {
        case .ios:
            return [
                ("\(home)/Library/Developer/Xcode/DerivedData", "Xcode DerivedData - 5-15GB", .xcode),
                ("\(home)/Library/Developer/Xcode/Archives", "Xcode Archives", .xcode),
                ("\(home)/Library/Developer/CoreSimulator", "Simuladores iOS", .simulator)
            ]
        case .android:
            return [("\(home)/.gradle/caches", "Gradle Cache", .gradle)]
        case .webNode:
            return [("\(home)/.npm/_cacache", "NPM Cache", .node), ("\(home)/Library/Caches/Yarn", "Yarn Cache", .node)]
        case .python:
            return [("\(home)/.cache/pip", "Pip Cache", .other)]
        case .flutter:
            return [("\(home)/.pub-cache", "Dart Pub Cache", .other)]
        case .ruby:
            return [("\(home)/.cocoapods/repos", "CocoaPods Repos", .other)]
        case .docker:
            return [("\(home)/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", "Docker Disk - 10-60GB", .docker)]
        }
    }
    
    func isDetected(from tools: [String]) -> Bool {
        let lower = tools.map { $0.lowercased() }
        switch self {
        case .ios: return lower.contains { $0.contains("xcode") }
        case .android: return lower.contains { $0.contains("android") || $0.contains("gradle") }
        case .webNode: return lower.contains { $0.contains("node") }
        case .python: return lower.contains { $0.contains("python") }
        case .flutter: return lower.contains { $0.contains("flutter") }
        case .ruby: return lower.contains { $0.contains("cocoapods") }
        case .docker: return lower.contains { $0.contains("docker") }
        }
    }
}

enum UserProfile: String, CaseIterable, Identifiable {
    case developer = "Developer"
    case designer = "Diseñador"
    case architect = "Arquitecto"
    case video = "Video Editor"
    case general = "General"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .developer: return "hammer.fill"
        case .designer: return "paintbrush.fill"
        case .architect: return "building.columns.fill"
        case .video: return "film.fill"
        case .general: return "person.fill"
        }
    }
    
    var description: String {
        switch self {
        case .developer: return "iOS, Android, Web, Python, Flutter, Docker"
        case .designer: return "【entity-Adobe¦canonical_name=Adobe】, 【entity-Figma¦canonical_name=Figma】"
        case .architect: return "【entity-AutoCAD¦canonical_name=AutoCAD】"
        case .video: return "DaVinci, Final Cut"
        case .general: return "Descargas y sistema"
        }
    }
}

final class ProfileService {
    static let shared = ProfileService()
    private let fm = FileManager.default
    private init() {}
    
    func detectProfile(from proInfo: ProDetectionResult) -> UserProfile {
        let tools = proInfo.detectedTools.map { $0.lowercased() }
        if tools.contains(where: { $0.contains("xcode") || $0.contains("android") || $0.contains("docker") || $0.contains("node") }) {
            return .developer
        }
        return .general
    }
    
    func detectSubProfiles(from proInfo: ProDetectionResult) -> [DevSubProfile] {
        DevSubProfile.allCases.filter { $0.isDetected(from: proInfo.detectedTools) }
    }
    
    func scanForProfile(_ profile: UserProfile, subProfiles: [DevSubProfile] = []) -> [DeepCleanItem] {
        var pathsToScan: [(path: String, desc: String, category: DeepCleanCategory)] = []
        
        if profile == .developer {
            let toScan = subProfiles.isEmpty ? DevSubProfile.allCases : subProfiles
            for sub in toScan {
                pathsToScan.append(contentsOf: sub.scanPaths)
            }
        } else {
            let home = ScannerService.realHomeDirectory.path
            pathsToScan = [
                ("\(home)/Library/Caches", "Caches generales", .caches),
                ("\(home)/Library/Logs", "Logs", .logs)
            ]
        }
        
        var items: [DeepCleanItem] = []
        
        for entry in pathsToScan {
            guard fm.fileExists(atPath: entry.path) else { continue }
            let sizeMB = fastFolderSize(path: entry.path)
            if sizeMB < 5 { continue }
            items.append(DeepCleanItem(name: URL(fileURLWithPath: entry.path).lastPathComponent, path: entry.path, sizeMB: sizeMB, category: entry.category, explanation: entry.desc))
        }
        
        return items.sorted { $0.sizeMB > $1.sizeMB }
    }
    
    private func fastFolderSize(path: String) -> Double {
        if let attrs = try? fm.attributesOfItem(atPath: path), let type = attrs[.type] as? FileAttributeType, type == .typeRegular {
            let size = (attrs[.size] as? UInt64) ?? 0
            return Double(size) / (1024 * 1024)
        }
        let url = URL(fileURLWithPath: path)
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
            if total > 100 * 1024 * 1024 * 1024 { break }
        }
        return Double(total) / (1024 * 1024)
    }
}
