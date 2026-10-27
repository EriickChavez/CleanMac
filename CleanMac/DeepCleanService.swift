//
//  DeepCleanService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

struct DeepCleanItem: Identifiable, Sendable, Equatable {
    let id = UUID(); let name: String; let path: String; let sizeMB: Double; let category: Category; let explanation: String
    enum Category: String { case xcode = "Xcode", docker = "Docker", system = "Sistema", nodeModules = "Node", externalTrash = "Disco Externo"
        var icon: String { switch self { case .xcode: "hammer.fill"; case .docker: "shippingbox.fill"; case .system: "macbook"; case .nodeModules: "chevron.left.forwardslash.chevron.right"; case .externalTrash: "trash.fill" } }
    }
    var sizeText: String { sizeMB > 1024 ? String(format: "%.2f GB", sizeMB/1024) : String(format: "%.0f MB", sizeMB) }
    static func == (lhs: DeepCleanItem, rhs: DeepCleanItem) -> Bool { lhs.id == rhs.id }
}

final class DeepCleanService: Sendable {
    static let shared = DeepCleanService()
    func scanDeepClean() -> [DeepCleanItem] {
        var items: [DeepCleanItem] = []; let home = FileManager.default.homeDirectoryForCurrentUser.path
        let checks = [("\(home)/Library/Developer/Xcode/DerivedData", "Xcode DerivedData", DeepCleanItem.Category.xcode, "Compilaciones temporales. Seguro borrar."),
                      ("\(home)/Library/Developer/Xcode/Archives", "Xcode Archives", .xcode, "Versiones viejas archivadas."),
                      ("/private/var/vm/sleepimage", "Sleep Image", .system, "Imagen de hibernación. 8GB.")]
        for c in checks { if let s = fastSize(path: c.0), s > 10 { items.append(DeepCleanItem(name: c.1, path: c.0, sizeMB: s, category: c.2, explanation: c.3)) } }
        let docker = "\(home)/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
        if let s = fastSize(path: docker), s > 100 { items.append(DeepCleanItem(name: "Docker.raw", path: docker, sizeMB: s, category: .docker, explanation: "Disco virtual Docker 30-60GB")) }
        return items.sorted { $0.sizeMB > $1.sizeMB }
    }
    private func fastSize(path: String) -> Double? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/du"); task.arguments = ["-sm", path]
        let pipe = Pipe(); task.standardOutput = pipe; task.standardError = Pipe(); try? task.run(); task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8), let mb = Double(out.components(separatedBy: "\t").first ?? "") { return mb }
        return nil
    }
    func delete(item: DeepCleanItem) throws { try FileManager.default.removeItem(atPath: item.path) }
}
