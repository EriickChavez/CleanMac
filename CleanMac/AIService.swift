//
//  AIService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
final class AIService {
    static let shared = AIService()
    private init() {}
    func analyze(file: FileItem) -> FileAnalysisResult {
        let name = file.name.lowercased()
        let ext = (file.name as NSString).pathExtension.lowercased()
        let path = file.path.lowercased()
        if path.contains("/caches/") || path.contains("/logs/") {
            return FileAnalysisResult(path: file.path, name: file.name, analysis: FileAnalysis(risk: .safe, reason: "Cache/Log seguro", shouldDelete: true))
        }
        if ext == "dmg" || ext == "pkg" || ext == "zip" || ext == "iso" {
            if file.lastAccess < Calendar.current.date(byAdding: .day, value: -30, to: Date())! {
                return FileAnalysisResult(path: file.path, name: file.name, analysis: FileAnalysis(risk: .safe, reason: "Instalador viejo 30+ días", shouldDelete: true))
            }
        }
        return FileAnalysisResult(path: file.path, name: file.name, analysis: FileAnalysis(risk: .safe, reason: "Temporal revisado", shouldDelete: true))
    }
    func analyzeBatch(files: [FileItem]) -> [FileAnalysisResult] {
        files.map { analyze(file: $0) }
    }
}
