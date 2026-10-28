//
//  Untitled.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
import CryptoKit

/// Encuentra duplicados agrupando por tamaño primero, luego hash
/// Así no hace hash de todo
final class DuplicateService {
    
    static let shared = DuplicateService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Scan por Path
    
    func findDuplicates(in path: String) -> [DuplicateGroup] {
        
        let url = URL(fileURLWithPath: path)
        
        // Seguridad: verificar que existe
        guard fileManager.fileExists(atPath: url.path) else {
            print("[DuplicateService] Path no existe: \(path)")
            return []
        }
        
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        var items: [FileItem] = []
        
        for fileURL in fileURLs {
            guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                continue
            }
            
            let fileItem = FileItem(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                sizeMB: Double(fileSize) / (1024.0 * 1024.0),
                lastAccess: Date()
            )
            
            items.append(fileItem)
        }
        
        return findDuplicates(in: items)
    }
    
    // MARK: - Find Duplicates Lógica Correcta
    
    func findDuplicates(in files: [FileItem]) -> [DuplicateGroup] {
        
        // Paso 1: Agrupar por tamaño redondeado
        // Si no tienen mismo tamaño, no pueden ser duplicados
        var filesBySize: [Double: [FileItem]] = [:]
        
        for file in files {
            let roundedSize = round(file.sizeMB * 10.0) / 10.0
            filesBySize[roundedSize, default: []].append(file)
        }
        
        var duplicateGroups: [DuplicateGroup] = []
        
        // Paso 2: Solo para grupos con mismo tamaño, hacer hash
        for (_, sameSizeFiles) in filesBySize {
            
            // Si solo hay 1 archivo con ese tamaño, no es duplicado
            guard sameSizeFiles.count > 1 else {
                continue
            }
            
            // Agrupar por hash (solo primer 1MB para ser rápido)
            var filesByHash: [String: [FileItem]] = [:]
            
            for file in sameSizeFiles {
                if let hash = hashFirstMegabyte(path: file.path) {
                    filesByHash[hash, default: []].append(file)
                }
            }
            
            // Crear grupos
            for (_, duplicateFiles) in filesByHash {
                if duplicateFiles.count > 1 {
                    let group = DuplicateGroup(files: duplicateFiles)
                    duplicateGroups.append(group)
                }
            }
        }
        
        print("[DuplicateService] Encontrados \(duplicateGroups.count) grupos de duplicados")
        
        return duplicateGroups
    }
    
    // MARK: - Hash Seguro y Rápido
    
    /// Solo hashea el primer MB para no leer archivos de 4GB completos
    private func hashFirstMegabyte(path: String) -> String? {
        
        guard let fileHandle = try? FileHandle(forReadingAtPath: path) else {
            return nil
        }
        
        defer {
            try? fileHandle.close()
        }
        
        let firstMBData = fileHandle.readData(ofLength: 1024 * 1024)
        
        guard !firstMBData.isEmpty else {
            return nil
        }
        
        let digest = SHA256.hash(data: firstMBData)
        
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        
        return hashString
    }
}
