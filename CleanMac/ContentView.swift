//
//  ContentView.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI
import AppKit
import QuickLookUI

// MARK: - Sidebar
enum SidebarItem: String, CaseIterable, Identifiable {
    case files = "Archivos"
    case duplicates = "Duplicados"
    case apps = "Apps y Caches"
    case deep = "Limpieza Profunda"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .files: return "doc.text.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .apps: return "app.badge.fill"
        case .deep: return "trash.slash.fill"
        }
    }
    var color: Color {
        switch self {
        case .files: return .blue
        case .duplicates: return .orange
        case .apps: return .purple
        case .deep: return .red
        }
    }
}

enum FileFilter: String, CaseIterable, Identifiable {
    case all = "Todos", images = "Imágenes", videos = "Videos", installers = "Instaladores", documents = "Docs", apk = "APK", safe = "✅ Seguro"
    var id: String { rawValue }
}

struct ThumbnailView: View {
    let path: String
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fill) }
            else { Color(nsColor: .controlBackgroundColor) }
        }
        .frame(width: 44, height: 44).clipped().cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .task { image = await ThumbnailService.shared.thumbnail(for: path) }
    }
}

// MARK: - Main
struct ContentView: View {
    @State private var selection: SidebarItem = .files
    @State private var files: [FileItem] = []
    @State private var extendedFiles: [FileItem] = []
    @State private var hiddenFiles: [FileItem] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var analysisResults: [FileAnalysisResult] = []
    @State private var errorMessage: String?
    @State private var isScanning = false
    @State private var isScanningHidden = false
    @State private var isScanningExtended = false
    @State private var isAnalyzing = false
    @State private var showHidden = false
    @State private var showDeleteSheet = false
    @State private var trashDays = 7
    @State private var proInfo = ProDetectionResult(isProUser: false, modeName: "Modo Simple", detectedTools: [])
    
    @State private var searchText = ""
    @State private var selectedFilter: FileFilter = .all
    @State private var sortByLargest = true
    @State private var showPreview: FileItem?
    @State private var selectedSmartTab = 0
    @State private var scanProgressText = "Preparando..."
    
    @State private var appCaches: [AppCacheInfo] = []
    @State private var isScanningApps = false
    @State private var selectedAppCache: AppCacheInfo?
    @State private var deepItems: [DeepCleanItem] = []
    @State private var isScanningDeep = false
    @State private var selectedDeepItem: DeepCleanItem?
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var isScanningDuplicates = false
    
    var allFiles: [FileItem] { files + extendedFiles + hiddenFiles }
    var selectedFiles: [FileItem] { allFiles.filter { selectedIDs.contains($0.id) } }
    var totalSelectedSize: Double { selectedFiles.reduce(0) { $0 + $1.sizeMB } / 1024.0 }
    
    var filteredFiles: [FileItem] {
        filteredFilesLogic(files: files)
    }
    
    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label {
                    Text(item.rawValue).font(.system(.body, design: .rounded))
                } icon: {
                    Image(systemName: item.icon).foregroundStyle(item.color).font(.system(size: 16, weight: .semibold))
                }
                .padding(.vertical, 4)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Label(proInfo.modeName, systemImage: proInfo.isProUser ? "hammer.fill" : "person.fill")
                        .font(.caption2).bold()
                        .foregroundStyle(proInfo.isProUser ? .purple : .secondary)
                }
            }
        } detail: {
            Group {
                switch selection {
                case .files: filesTab
                case .duplicates: duplicatesTab
                case .apps: appsTab
                case .deep: deepCleanTab
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: scanAllWithProgress) {
                        Label(isScanning ? "Escaneando..." : "Escanear", systemImage: "arrow.triangle.2.circlepath")
                    }.disabled(isScanning)
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 750)
        .onAppear { proInfo = ProDetectorService.shared.detect(); if files.isEmpty { scanAllWithProgress() } }
        .task { SmartTrashService.shared.cleanupExpired() }
        .sheet(isPresented: $showDeleteSheet) { deleteSheet }
        .sheet(item: $showPreview) { file in previewSheet(file) }
    }
    
    // MARK: - Files Tab con Loading + A+B
    var filesTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar", text: $searchText).textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .frame(width: 260)
                
                Picker("", selection: $selectedFilter) {
                    ForEach(FileFilter.allCases) { f in Text(f.rawValue).tag(f) }
                }.pickerStyle(.menu).frame(width: 140).labelsHidden()
                
                Spacer()
                
                if isScanning || isScanningExtended {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(scanProgressText).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }
            .padding(12)
            Divider()
            
            HStack(spacing: 8) {
                Picker("", selection: $selectedSmartTab) {
                    Text("📦 Grandes (>500MB)").tag(0)
                    Text("🕰️ Viejos (90d+)").tag(1)
                    Text("💿 Instaladores").tag(2)
                    Text("📁 Todo").tag(3)
                }.pickerStyle(.segmented).frame(width: 520)
                Spacer()
                if isAnalyzing { ProgressView().controlSize(.small); Text("Analizando IA...").font(.caption).foregroundStyle(.secondary) }
                else if !selectedFiles.isEmpty {
                    Button("Analizar \(selectedFiles.count) con IA") { analyze() }.buttonStyle(.borderedProminent).controlSize(.small)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
            
            HStack(spacing: 6) {
                Toggle("Mostrar ocultos del sistema (>100MB)", isOn: $showHidden).toggleStyle(.checkbox).font(.caption).onChange(of: showHidden) { _, on in if on { scanHidden() } }
                Spacer()
                if analysisResults.contains(where: { $0.analysis.risk == .green }) {
                    Button("Seleccionar todo lo seguro") { selectAllSafe() }.buttonStyle(.borderedProminent).tint(.green).controlSize(.mini)
                }
            }.padding(.horizontal, 12).padding(.bottom, 6)
            
            if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red).padding(.horizontal) }
            
            // Loading skeleton
            if isScanning && files.isEmpty && extendedFiles.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.3)
                    Text("Escaneando Downloads, Desktop, Movies y Logs...")
                        .font(.system(.body, design: .rounded)).foregroundStyle(.secondary)
                    Text(scanProgressText).font(.caption).foregroundStyle(.tertiary).monospaced()
                    ForEach(0..<6, id: \.self) { _ in
                        HStack(spacing: 12) {
                            Circle().fill(Color.gray.opacity(0.2)).frame(width: 18, height: 18)
                            RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)).frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(width: 200, height: 12)
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.1)).frame(width: 120, height: 8)
                            }
                            Spacer()
                        }.padding(.horizontal, 16).redacted(reason: .placeholder)
                    }
                }.frame(maxHeight: .infinity)
            } else {
                List {
                    if !analysisResults.isEmpty {
                        Section {
                            ForEach(analysisResults) { result in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle().fill(colorForRisk(result.analysis.risk)).frame(width: 10, height: 10).padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack { Text(result.name).font(.system(.body, design: .rounded).bold()).lineLimit(1); Spacer(); Text(result.analysis.risk.rawValue).font(.caption2).bold().padding(.horizontal, 6).padding(.vertical, 2).background(colorForRisk(result.analysis.risk).opacity(0.15), in: Capsule()) }
                                        Text(result.analysis.explanation_es).font(.callout).foregroundStyle(.secondary)
                                        Text(result.analysis.recommendation).font(.caption).foregroundStyle(.tertiary)
                                    }
                                }.padding(.vertical, 4)
                            }
                            Button("Borrar seleccionados") { showDeleteSheet = true }.buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                        } header: { Text("Análisis IA - \(proInfo.modeName)").font(.caption2).bold().foregroundStyle(.secondary) }
                    }
                    
                    let displayFiles = currentDisplayFiles()
                    
                    Section {
                        if displayFiles.isEmpty {
                            ContentUnavailableView(isScanning ? "Escaneando..." : "Sin archivos", systemImage: "doc.text.magnifyingglass", description: Text(searchText.isEmpty ? "No hay archivos en esta categoría" : "No hay resultados para '\(searchText)'"))
                        } else {
                            ForEach(displayFiles) { file in fileRow(file).onTapGesture(count: 2) { showPreview = file } }
                        }
                    } header: {
                        HStack {
                            Text(smartTabName).font(.caption2).bold()
                            Spacer()
                            if isScanningExtended { ProgressView().controlSize(.mini) }
                            Text("\(displayFiles.count) • \(String(format: "%.2f GB", displayFiles.reduce(0){$0+$1.sizeMB}/1024))").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    
                    if showHidden {
                        Section {
                            if isScanningHidden { HStack { ProgressView().controlSize(.small); Text("Escaneando caches del sistema…").font(.caption).foregroundStyle(.secondary) } }
                            else if hiddenFiles.isEmpty { Text("No hay caches >100MB").font(.caption).foregroundStyle(.secondary) }
                            else { ForEach(hiddenFiles) { file in fileRow(file) } }
                        } header: { Text("Sistema (>100MB)").font(.caption2).bold().foregroundStyle(.orange) }
                    }
                }.listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    var duplicatesTab: some View {
        VStack(spacing: 0) {
            HStack { Text("Desperdiciado: \(String(format: "%.2f GB", duplicateGroups.reduce(0){$0+$1.totalWastedMB}/1024))").bold().foregroundStyle(.red).font(.system(.body, design: .rounded)); Spacer(); Button("Buscar Duplicados") { scanDuplicates() }.buttonStyle(.borderedProminent).controlSize(.small); if isScanningDuplicates { ProgressView().controlSize(.small) } }.padding(12)
            Divider()
            List {
                if duplicateGroups.isEmpty {
                    ContentUnavailableView("Sin duplicados", systemImage: "doc.on.doc", description: Text("No encontramos archivos con contenido idéntico"))
                } else {
                    ForEach(duplicateGroups) { group in
                        Section {
                            ForEach(group.files) { file in fileRow(file) }
                            Button("Borrar duplicados (conservar 1)") { let toDelete = Array(group.files.dropFirst()); try? SmartTrashService.shared.deleteNow(files: toDelete); scanAllWithProgress(); scanDuplicates() }.buttonStyle(.bordered).tint(.red).controlSize(.mini)
                        } header: { HStack { Text("\(group.files.count) copias • Desperdiciado \(group.sizeText)").font(.caption2).bold(); Spacer(); Text(String(group.hash.prefix(8))).font(.caption2).foregroundStyle(.tertiary).monospaced() } }
                    }
                }
            }.listStyle(.inset(alternatesRowBackgrounds: true))
        }.onAppear { if !files.isEmpty { scanDuplicates() } }
    }
    
    var appsTab: some View {
        VStack(spacing: 0) {
            HStack { Text("Total en caches: \(String(format: "%.2f GB", appCaches.reduce(0){$0+$1.totalSizeMB}/1024))").bold().font(.system(.body, design: .rounded)); Spacer(); Button("Escanear") { scanApps() }.buttonStyle(.borderedProminent).controlSize(.small); if isScanningApps { ProgressView().controlSize(.small) } }.padding(12)
            Divider()
            List(appCaches) { app in
                HStack(spacing: 12) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8)) } else { RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.15)).frame(width: 36, height: 36).overlay { Image(systemName: "app.fill").foregroundStyle(.purple) } }
                    VStack(alignment: .leading, spacing: 2) { Text(app.name).font(.system(.body, design: .rounded).bold()); Text(app.cachePaths.first ?? "").font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                    Spacer(); VStack(alignment: .trailing, spacing: 2) { Text(app.sizeText).bold().monospacedDigit(); Button("Limpiar") { selectedAppCache = app }.buttonStyle(.bordered).tint(.red).controlSize(.small) }
                }.padding(.vertical, 4)
            }.listStyle(.inset(alternatesRowBackgrounds: true))
                .alert(item: $selectedAppCache) { app in Alert(title: Text("¿Limpiar \(app.name)?"), message: Text("Se borrarán \(app.sizeText) de caché"), primaryButton: .destructive(Text("Borrar")) { try? AppCacheService.shared.clearCache(for: app); scanApps() }, secondaryButton: .cancel()) }
        }.onAppear { scanApps() }
    }
    
    var deepCleanTab: some View {
        VStack(spacing: 0) {
            HStack { Text("Oculto: \(String(format: "%.2f GB", deepItems.reduce(0){$0+$1.sizeMB}/1024))").bold().foregroundStyle(.red).font(.system(.body, design: .rounded)); Spacer(); Button("Escanear Sistema") { scanDeep() }.buttonStyle(.borderedProminent).controlSize(.small); if isScanningDeep { ProgressView().controlSize(.small) } }.padding(12)
            Divider()
            List(deepItems) { item in
                HStack(spacing: 12) {
                    ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)).frame(width: 36, height: 36); Image(systemName: item.category.icon).foregroundStyle(.red) }
                    VStack(alignment: .leading, spacing: 2) { Text(item.name).font(.system(.body, design: .rounded).bold()); Text(item.explanation).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                    Spacer(); VStack(alignment: .trailing) { Text(item.sizeText).bold().monospacedDigit(); Button("Borrar") { selectedDeepItem = item }.buttonStyle(.bordered).tint(.red).controlSize(.small) }
                }.padding(.vertical, 4)
            }.listStyle(.inset(alternatesRowBackgrounds: true))
                .alert(item: $selectedDeepItem) { item in Alert(title: Text("¿Borrar \(item.name)?"), message: Text(item.explanation), primaryButton: .destructive(Text("Borrar \(item.sizeText)")) { try? DeepCleanService.shared.delete(item: item); scanDeep() }, secondaryButton: .cancel()) }
        }.onAppear { scanDeep() }
    }
    
    // MARK: - Helpers
    @ViewBuilder private func fileRow(_ file: FileItem) -> some View {
        HStack(spacing: 12) {
            Button { toggle(file) } label: { Image(systemName: selectedIDs.contains(file.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(selectedIDs.contains(file.id) ? Color.accentColor : .secondary).font(.system(size: 18)) }.buttonStyle(.plain)
            ThumbnailView(path: file.path)
            VStack(alignment: .leading, spacing: 2) { Text(file.name).font(.system(.body, design: .rounded)).lineLimit(1).truncationMode(.middle); Text(file.typeDescription + " • " + abbreviated(file.path)).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
            Spacer()
            if let result = analysisResults.first(where: { $0.id == file.id }) { Circle().fill(colorForRisk(result.analysis.risk)).frame(width: 10, height: 10).shadow(color: colorForRisk(result.analysis.risk).opacity(0.5), radius: 4) }
            Text(sizeText(file.sizeMB)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Text(dateText(file.lastAccess)).font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 120, alignment: .trailing)
        }.padding(.vertical, 4).contentShape(Rectangle())
    }
    
    private var deleteSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.fill").font(.system(size: 40)).foregroundStyle(.red)
            Text("¿Borrar \(selectedFiles.count) archivos?").font(.system(.title3, design: .rounded).bold())
            Text("\(String(format: "%.2f GB", totalSelectedSize)) se liberarán").foregroundStyle(.secondary).font(.system(.body, design: .rounded))
            VStack(spacing: 12) {
                HStack { Text("Papelera inteligente:").font(.system(.body, design: .rounded)); Spacer(); Text("\(trashDays) días").bold().monospacedDigit() }
                Slider(value: Binding(get: { Double(trashDays) }, set: { trashDays = Int($0) }), in: 1...30, step: 1).tint(.red)
            }.padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            HStack { Button("Cancelar") { showDeleteSheet = false }.keyboardShortcut(.cancelAction); Spacer(); Button("Papelera Inteligente") { try? SmartTrashService.shared.moveToSmartTrash(files: selectedFiles, days: trashDays); afterDelete() }.buttonStyle(.bordered); Button("Borrar AHORA") { try? SmartTrashService.shared.deleteNow(files: selectedFiles); afterDelete() }.buttonStyle(.borderedProminent).tint(.red) }
        }.padding(24).frame(width: 520).background(.ultraThinMaterial)
    }
    
    private func previewSheet(_ file: FileItem) -> some View {
        VStack(spacing: 12) {
            Text(file.name).font(.system(.headline, design: .rounded)).padding(.top)
            if let nsImage = NSImage(contentsOfFile: file.path) { Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 600, maxHeight: 500).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 10) }
            else { ContentUnavailableView("Sin preview", systemImage: "eye.slash", description: Text(file.path)) }
            Text(file.path).font(.caption).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle).padding(.horizontal)
            Button("Cerrar") { showPreview = nil }.buttonStyle(.borderedProminent).padding(.bottom)
        }.frame(width: 700, height: 650).background(.ultraThinMaterial)
    }
    
    private func afterDelete() { showDeleteSheet = false; selectedIDs.removeAll(); analysisResults.removeAll(); scanAllWithProgress() }
    private func toggle(_ file: FileItem) { if selectedIDs.contains(file.id) { selectedIDs.remove(file.id) } else { selectedIDs.insert(file.id) } }
    private func selectAllSafe() { let safeIDs = analysisResults.filter { $0.analysis.risk == .green }.map { $0.id }; selectedIDs = Set(safeIDs) }
    private func colorForRisk(_ risk: RiskLevel) -> Color { switch risk { case .green: .green; case .yellow: .yellow; case .red: .red } }
    private var smartTabName: String {
        switch selectedSmartTab {
        case 0: return "Grandes (más GB)"
        case 1: return "Viejos (90+ días)"
        case 2: return "Instaladores"
        default: return "Todos (\(files.count + extendedFiles.count))"
        }
    }
    private func currentDisplayFiles() -> [FileItem] {
        let combined = files + extendedFiles
        let base = combined.isEmpty ? files : combined
        let filtered = filteredFilesLogic(files: base)
        switch selectedSmartTab {
        case 0: return ExtendedScannerService.shared.largeFiles(from: filtered)
        case 1: return ExtendedScannerService.shared.oldFiles(from: filtered)
        case 2: return ExtendedScannerService.shared.installers(from: filtered)
        default: return filtered
        }
    }
    private func filteredFilesLogic(files: [FileItem]) -> [FileItem] {
        var result = files
        if !searchText.isEmpty { result = result.filter { $0.name.lowercased().contains(searchText.lowercased()) } }
        switch selectedFilter {
        case .images: result = result.filter { ["jpg","jpeg","png","heic","webp"].contains(($0.name as NSString).pathExtension.lowercased()) }
        case .videos: result = result.filter { ["mp4","mov","avi","mkv"].contains(($0.name as NSString).pathExtension.lowercased()) }
        case .installers: result = result.filter { ["dmg","pkg","zip","rar"].contains(($0.name as NSString).pathExtension.lowercased()) }
        case .documents: result = result.filter { ["pdf","doc","docx"].contains(($0.name as NSString).pathExtension.lowercased()) }
        case .apk: result = result.filter { ($0.name as NSString).pathExtension.lowercased() == "apk" }
        case .safe: result = result.filter { file in analysisResults.first(where: { $0.id == file.id })?.analysis.risk == .green }
        case .all: break
        }
        if sortByLargest { result.sort { $0.sizeMB > $1.sizeMB } } else { result.sort { $0.lastAccess > $1.lastAccess } }
        return result
    }
    private func scanAllWithProgress() {
        isScanning = true; isScanningExtended = true; errorMessage = nil
        scanProgressText = "Escaneando Downloads..."
        Task {
            do {
                let downloads = try await Task.detached(priority: .userInitiated) { try ScannerService.shared.scanDownloads() }.value
                await MainActor.run { files = downloads; scanProgressText = "Escaneando Desktop, Movies y Logs..." }
                let extended = await Task.detached(priority: .utility) { (try? ExtendedScannerService.shared.scanExtended()) ?? [] }.value
                await MainActor.run { extendedFiles = extended; isScanning = false; isScanningExtended = false; scanProgressText = "Listo: \(files.count + extended.count) archivos"; scanDuplicates() }
            } catch { await MainActor.run { errorMessage = error.localizedDescription; isScanning = false; isScanningExtended = false } }
        }
    }
    private func scan() { scanAllWithProgress() }
    private func scanHidden() { isScanningHidden = true; Task { let r = await Task.detached(priority: .utility) { ScannerService.shared.scanHiddenCaches() }.value; hiddenFiles = r; isScanningHidden = false } }
    private func analyze() { isAnalyzing = true; analysisResults = []; Task { let results = await AIService.shared.analyzeBatch(files: selectedFiles); analysisResults = results; isAnalyzing = false } }
    private func scanApps() { isScanningApps = true; Task { let result = await Task.detached(priority: .userInitiated) { AppCacheService.shared.scanAllAppCaches() }.value; appCaches = result; isScanningApps = false } }
    private func scanDeep() { isScanningDeep = true; Task { let result = await Task.detached(priority: .userInitiated) { DeepCleanService.shared.scanDeepClean() }.value; deepItems = result; isScanningDeep = false } }
    private func scanDuplicates() { isScanningDuplicates = true; Task { let all = files + extendedFiles; let result = await Task.detached(priority: .userInitiated) { DuplicateService.shared.findDuplicates(in: all.isEmpty ? files : all) }.value; duplicateGroups = result; isScanningDuplicates = false } }
    private func sizeText(_ megabytes: Double) -> String { megabytes > 1024 ? String(format: "%.2f GB", megabytes/1024) : String(format: "%.0f MB", megabytes) }
    private func dateText(_ date: Date) -> String { guard date != .distantPast else { return "—" }; return date.formatted(date: .abbreviated, time: .shortened) }
    private func abbreviated(_ path: String) -> String { let home = ScannerService.realHomeDirectory.path; guard path.hasPrefix(home) else { return path }; return "~" + path.dropFirst(home.count) }
}

extension View {
    func shimmer() -> some View { self } // placeholder para no romper, macOS no tiene shimmer nativo
}
