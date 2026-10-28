//
//  ThumbnailService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import AppKit

/// Thumbnails con NSCache para no recalcular
/// Antes no tenía cache y por eso era lento
final class ThumbnailService {
    
    static let shared = ThumbnailService()
    
    private let cache: NSCache<NSString, NSImage>
    
    private init() {
        self.cache = NSCache<NSString, NSImage>()
        self.cache.countLimit = 200
        self.cache.totalCostLimit = 50 * 1024 * 1024 // 50MB max
        self.cache.name = "com.cleanmac.thumbnails"
    }
    
    // MARK: - Get Thumbnail
    
    func thumbnail(for path: String) -> NSImage {
        
        let cacheKey = path as NSString
        
        // Si está en cache, devolver inmediato
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Icono del sistema - nativo y rápido
        // No usar QuickLook que es lento
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)
        
        // Guardar en cache
        cache.setObject(icon, forKey: cacheKey)
        
        return icon
    }
    
    // MARK: - Clear
    
    func clearCache() {
        cache.removeAllObjects()
        print("[ThumbnailService] Cache limpiada")
    }
}
