//
//  AIService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

final class AIService: Sendable {
    static let shared = AIService()
    private init() {}
    
    func analyzeBatch(files: [FileItem]) async -> [FileAnalysisResult] {
        var results: [FileAnalysisResult] = []
        for i in stride(from: 0, to: files.count, by: 10) {
            let batch = Array(files[i..<min(i+10, files.count)])
            for file in batch {
                let analysis = analyzeSingle(file: file)
                results.append(FileAnalysisResult(path: file.path, name: file.name, analysis: analysis, usedLLM: false))
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return results
    }
    
    private func analyzeSingle(file: FileItem) -> FileAnalysis {
        let name = file.name.lowercased()
        let path = file.path.lowercased()
        let ext = (file.name as NSString).pathExtension.lowercased()
        let size = file.sizeMB
        
        // APK
        if ext == "apk" {
            return FileAnalysis(
                risk: .yellow,
                explanation_es: "Paquete de instalación Android (APK) de '\(file.name)'. Es el instalador de house-control. Si ya instalaste la app en tu celular/emulador, este archivo ya no sirve y solo ocupa espacio. Si no lo has instalado, guárdalo.",
                recommendation: "Si ya instalaste la app, seguro borrar. Si no, mover a proyecto Android."
            )
        }
        
        // PDF CV
        if ext == "pdf" && (name.contains("cv") || name.contains("resume")) {
            return FileAnalysis(
                risk: .yellow,
                explanation_es: "Documento PDF que parece ser tu CV versión 4 v3. Pesa \(String(format: "%.1f MB", size)). Los CVs se acumulan rápido. Verifica si esta es la última versión.",
                recommendation: "Conservar solo la última versión de tu CV. Las viejas borrar."
            )
        }
        
        // Imágenes con hash (como la jpg de la captura)
        if ["jpg","jpeg","png","heic"].contains(ext) && name.count > 20 && name.contains("-") {
            return FileAnalysis(
                risk: .green,
                explanation_es: "Imagen con nombre hash (probable caché de WhatsApp, Telegram o navegador). Pesa \(String(format: "%.1f MB", size)). Estas imágenes son temporales y se regeneran.",
                recommendation: "Seguro borrar - es caché de mensajería"
            )
        }
        
        // Imágenes normales
        if ["jpg","jpeg","png","heic","webp"].contains(ext) {
            return FileAnalysis(
                risk: .yellow,
                explanation_es: "Imagen \(ext.uppercased()) de \(String(format: "%.1f MB", size)). Revisa si es foto importante o screenshot viejo.",
                recommendation: "Revisar visualmente con el thumbnail antes de borrar"
            )
        }
        
        // Sistema
        if path.contains("com.apple") || path.contains("/private/var") {
            return FileAnalysis(
                risk: .red,
                explanation_es: "Archivo del sistema macOS en \(file.path). Parte de \(path.components(separatedBy: "/").suffix(2).first ?? "sistema").",
                recommendation: "NO borrar - Puede romper macOS"
            )
        }
        
        // Caches
        if path.contains("caches") || path.contains(".npm") || path.contains("homebrew") || path.contains("deriveddata") {
            return FileAnalysis(
                risk: .green,
                explanation_es: "Caché temporal en \(file.path.components(separatedBy: "/").suffix(2).joined(separator: "/")). La app lo recreará. Ocupa \(String(format: "%.0f MB", size)).",
                recommendation: "Seguro borrar - Libera \(String(format: "%.0f MB", size))"
            )
        }
        
        // Instaladores
        if ["dmg","pkg","zip","rar"].contains(ext) {
            return FileAnalysis(
                risk: .green,
                explanation_es: "Instalador \(ext.uppercased()) de \(String(format: "%.1f MB", size)). Si ya instalaste el programa, ya no necesitas el instalador.",
                recommendation: "Si ya instalaste, borrar instalador"
            )
        }
        
        // Default pero con más contexto
        return FileAnalysis(
            risk: .yellow,
            explanation_es: "Archivo \(file.typeDescription) de \(String(format: "%.2f MB", size)) en Downloads. Nombre: \(file.name). Último acceso: \(file.lastAccess.formatted(date: .abbreviated, time: .omitted)).",
            recommendation: "Revisar si lo necesitas. Si tiene más de 30 días sin abrir, seguro borrar."
        )
    }
}
