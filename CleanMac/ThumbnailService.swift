//
//  ThumbnailService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
import AppKit
import QuickLookThumbnailing

final class ThumbnailService: Sendable {
    static let shared = ThumbnailService()
    private let cache = NSCache<NSString, NSImage>()
    func thumbnail(for path: String) async -> NSImage? {
        let key = path as NSString; if let c = cache.object(forKey: key) { return c }
        let url = URL(fileURLWithPath: path)
        let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 64, height: 64), scale: 2, representationTypes: .thumbnail)
        do { let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: req); cache.setObject(rep.nsImage, forKey: key); return rep.nsImage }
        catch { return NSWorkspace.shared.icon(forFile: path) }
    }
}
