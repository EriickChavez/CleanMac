//
//  ProDetectorService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

final class ProDetectorService: Sendable {
    static let shared = ProDetectorService()
    func detect() -> ProDetectionResult {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var tools: [String] = []
        if FileManager.default.fileExists(atPath: "/Applications/Xcode.app") { tools.append("Xcode") }
        if FileManager.default.fileExists(atPath: "\(home)/Library/Android") { tools.append("Android Studio") }
        if FileManager.default.fileExists(atPath: "/Applications/Docker.app") { tools.append("Docker") }
        let isPro = !tools.isEmpty
        return ProDetectionResult(isProUser: isPro, modeName: isPro ? "Modo Pro (\(tools.joined(separator: ", ")))": "Modo Simple", detectedTools: tools)
    }
}
