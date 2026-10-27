//
//  Models.swift.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//
import Foundation

struct FileItem: Identifiable, Sendable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let sizeMB: Double
    let lastAccess: Date
    var isHidden: Bool = false
    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.path == rhs.path }
    
    var typeDescription: String {
        let ext = (name as NSString).pathExtension.lowercased()
        if ["jpg","jpeg","png","heic","webp","tiff"].contains(ext) { return "Imagen" }
        if ["mp4","mov","avi","mkv"].contains(ext) { return "Video" }
        if ["zip","dmg","pkg","rar"].contains(ext) { return "Instalador" }
        if ["pdf"].contains(ext) { return "Documento" }
        return ext.isEmpty ? "Archivo" : ext.uppercased()
    }
}

enum RiskLevel: String, Sendable { case green = "SAFE", yellow = "CAUTION", red = "DANGER" }
struct FileAnalysis: Sendable { let risk: RiskLevel; let explanation_es: String; let recommendation: String }
struct FileAnalysisResult: Identifiable, Sendable, Equatable {
    let id = UUID(); let path: String; let name: String; let analysis: FileAnalysis; let usedLLM: Bool
    static func == (lhs: FileAnalysisResult, rhs: FileAnalysisResult) -> Bool { lhs.id == rhs.id }
}
struct ProDetectionResult: Sendable { let isProUser: Bool; let modeName: String; let detectedTools: [String] }
