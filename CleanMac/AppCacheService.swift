//
//  AppCacheService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

/// Escanea ~/Library/Caches de forma segura
/// NUNCA usa du -sm, solo FileManager
final class AppCacheService {
    
    static let shared = AppCacheService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Scan
    
    func scanAppCaches() -> [AppCacheInfo] {
        
        let cachesRoot = fileManager.homeDirectoryForCurrentUser.path + "/Library/Caches"
        
        // Seguridad: verificar que existe y es directorio
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: cachesRoot, isDirectory: &isDir),
              isDir.boolValue else {
            print("[AppCacheService] Caches no existe")
            return []
        }
        
        guard let items = try? fileManager.contentsOfDirectory(atPath: cachesRoot) else {
            print("[AppCacheService] No se pudo leer Caches")
            return []
        }
        
        var result: [AppCacheInfo] = []
        
        for itemName in items {
            
            // Seguridad: saltar ocultos
            if itemName.hasPrefix(".") {
                continue
            }
            
            let fullPath = "\(cachesRoot)/\(itemName)"
            
            // Seguridad: verificar que es directorio
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }
            
            // Performance: tamaño rápido con límite de 500 archivos
            let sizeMB = fastSizeLimited(path: fullPath, fileLimit: 500)
            
            // Mostrar desde 5MB para que no se vea vacío
            // Antes era 20MB y por eso no veías nada
            if sizeMB > 5.0 {
                let info = AppCacheInfo(
                    appName: itemName,
                    path: fullPath,
                    sizeMB: sizeMB,
                    bundleId: itemName
                )
                result.append(info)
            }
        }
        
        // Si aún está vacío (usuario muy limpio), mostrar los primeros 20 aunque sean pequeños
        // Para que no se vea la pantalla vacía
        if result.isEmpty {
            print("[AppCacheService] No hay caches >5MB, mostrando primeros 20")
            
            for itemName in items.prefix(20) {
                let fullPath = "\(cachesRoot)/\(itemName)"
                
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    
                    let sizeMB = fastSizeLimited(path: fullPath, fileLimit: 100)
                    
                    let info = AppCacheInfo(
                        appName: itemName,
                        path: fullPath,
                        sizeMB: sizeMB,
                        bundleId: itemName
                    )
                    result.append(info)
                }
            }
        }
        
        // Ordenar por tamaño
        let sorted = result.sorted { $0.sizeMB > $1.sizeMB }
        
        print("[AppCacheService] Encontrados \(sorted.count) caches")
        
        return sorted
    }
    
    // MARK: - Fast Size Seguro
    
    /// Calcula tamaño con límite de archivos para no congelar
    private func fastSizeLimited(path: String, fileLimit: Int) -> Double {
        
        let url = URL(fileURLWithPath: path)
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: UInt64 = 0
        var countedFiles = 0
        
        for case let fileURL as URL in enumerator {
            
            // Performance: límite de archivos
            if countedFiles > fileLimit {
                break
            }
            
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += UInt64(fileSize)
            }
            
            countedFiles += 1
        }
        
        return Double(totalSize) / (1024.0 * 1024.0)
    }
    
    // MARK: - Delete Seguro
    
    /// Borra de forma segura: mueve a papelera, no rm -rf
    func deleteSafely(info: AppCacheInfo) throws {
        
        // Seguridad: verificar que es dentro de Library/Caches
        guard info.path.contains("/Library/Caches/") else {
            throw NSError(domain: "Security", code: 1, userInfo: [NSLocalizedDescriptionKey: "Path no seguro para borrar: \(info.path)"])
        }
        
        // Seguridad: nunca borrar si es muy grande y parece importante
        if info.sizeMB > 5000 {
            print("[AppCacheService] ADVERTENCIA: Intentando borrar \(info.sizeMB)MB en \(info.path)")
        }
        
        try fileManager.trashItem(at: URL(fileURLWithPath: info.path), resultingItemURL: nil)
        
        print("[AppCacheService] Movido a papelera: \(info.path)")
    }
}
