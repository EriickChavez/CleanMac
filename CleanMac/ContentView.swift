//
//  ContentView.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI

enum Tab: String, CaseIterable {
    case inicio = "Inicio"
    case archivos = "Archivos"
    case duplicados = "Duplicados"
    case apps = "Apps y Caches"
    case profunda = "Limpieza Profunda"
    
    var icon: String {
        switch self {
        case .inicio: return "house.fill"
        case .archivos: return "doc.fill"
        case .duplicados: return "doc.on.doc.fill"
        case .apps: return "shippingbox.fill"
        case .profunda: return "trash.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .inicio: return .green
        case .archivos: return .blue
        case .duplicados: return .orange
        case .apps: return .purple
        case .profunda: return .red
        }
    }
}

struct ContentView: View {
    
    // MARK: - State
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @State private var selectedTab: Tab = .inicio
    @State private var showSettings = false
    
    @StateObject private var dashboard = DashboardService.shared
    @StateObject private var menuBar = MenuBarService.shared
    
    @State private var isScanning = false
    
    @State private var files: [FileItem] = []
    @State private var extendedFiles: [FileItem] = []
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var appCaches: [AppCacheInfo] = []
    @State private var deepCleanItems: [DeepCleanItem] = []
    @State private var profileItems: [DeepCleanItem] = []
    
    @State private var searchText = ""
    @State private var selectedProfile: UserProfile = .general
    @State private var selectedSubProfiles: Set<DevSubProfile> = Set(DevSubProfile.allCases)
    @State private var proInfo: ProDetectionResult?
    @State private var smartFilter: String = "Todos"
    
    @State private var totalGB: Double = 0
    @State private var profileTotalGB: Double = 0
    
    // MARK: - Computed
    
    var filteredFiles: [FileItem] {
        var list = selectedTab == .archivos ? files : extendedFiles
        
        if searchText.count > 1 {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        switch smartFilter {
        case "Grandes":
            list = list.filter { $0.sizeMB > 200 }
        case "Viejos":
            let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
            list = list.filter { $0.lastAccess < cutoff }
        case "Instaladores":
            list = list.filter { ["dmg", "pkg", "zip", "iso"].contains(($0.name as NSString).pathExtension.lowercased()) }
        default:
            break
        }
        
        return list.sorted { $0.sizeMB > $1.sizeMB }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            } else {
                mainContent
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            Task {
                await initialScan()
            }
        }
    }
    
    // MARK: - Main Content
    
    var mainContent: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .foregroundColor(tab.color)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem {
                    Button {
                        Task {
                            await scanAll()
                        }
                    } label: {
                        Label("Escanear", systemImage: "arrow.clockwise")
                    }
                    .disabled(isScanning)
                    .keyboardShortcut("r", modifiers: .command)
                }
            }
        } detail: {
            VStack(spacing: 0) {
                
                if selectedTab != .inicio {
                    topBar
                }
                
                if isScanning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Escaneando de forma segura...")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Esto tarda 2-3 segundos, no congela tu Mac")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                } else {
                    switch selectedTab {
                    case .inicio:
                        HomeView(dashboard: dashboard, onScan: { Task { await scanAll() } }, totalGB: totalGB, profileItems: profileItems)
                    case .archivos:
                        filesList
                    case .duplicados:
                        duplicatesList
                    case .apps:
                        appCachesList
                    case .profunda:
                        deepCleanList
                    }
                }
            }
        }
    }
    
    // MARK: - Top Bar
    
    var topBar: some View {
        VStack(spacing: 0) {
            
            if selectedTab == .profunda {
                profilePickerBar
            }
            
            HStack {
                TextField("Buscar...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
                
                Spacer()
                
                if selectedTab == .archivos {
                    Picker("", selection: $smartFilter) {
                        Text("Todos").tag("Todos")
                        Text("Grandes >200MB").tag("Grandes")
                        Text("Viejos 90d+").tag("Viejos")
                        Text("Instaladores").tag("Instaladores")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 400)
                }
                
                Spacer()
                
                Text(String(format: "%.2f GB", selectedTab == .profunda ? profileTotalGB : totalGB))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // BOTÓN GRANDE DE REFRESH
                Button {
                    Task { await scanAll() }
                } label: {
                    Label("Refrescar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)
                .padding(.leading, 12)
            }
            .padding(12)
            
            Divider()
        }
    }
    
    // MARK: - Profile Picker
    
    var profilePickerBar: some View {
        VStack(spacing: 8) {
            
            HStack {
                Text("Perfil")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $selectedProfile) {
                    ForEach(UserProfile.allCases, id: \.self) { p in
                        Label(p.rawValue, systemImage: p.icon).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                
                Text(selectedProfile.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if selectedProfile == .developer {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(DevSubProfile.allCases) { sub in
                            let isSelected = selectedSubProfiles.contains(sub)
                            
                            Button {
                                if isSelected {
                                    selectedSubProfiles.remove(sub)
                                } else {
                                    selectedSubProfiles.insert(sub)
                                }
                                Task { await scanProfile() }
                            } label: {
                                Label(sub.rawValue, systemImage: sub.icon)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.purple : Color.white.opacity(0.1))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            HStack {
                Label("Developer - \(profileItems.count) carpetas", systemImage: "hammer.fill")
                    .foregroundColor(.purple)
                    .font(.caption)
                    .bold()
                
                Spacer()
                
                Text(String(format: "%.2f GB", profileTotalGB))
                    .foregroundColor(.purple)
                    .font(.caption)
                    .bold()
            }
            
            Divider()
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Lists
    
    var filesList: some View {
        List(filteredFiles, id: \.id) { file in
            HStack {
                Image(nsImage: ThumbnailService.shared.thumbnail(for: file.path))
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
                
                VStack(alignment: .leading) {
                    Text(file.name)
                        .lineLimit(1)
                    Text(file.abbreviatedPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(file.sizeText)
                    .bold()
                    .font(.caption)
                
                Button("Borrar") {
                    deleteFile(file)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
        }
    }
    
    var duplicatesList: some View {
        Group {
            if duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("No hay duplicados")
                        .bold()
                    
                    Text("Tu carpeta Downloads está limpia")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Escanear de nuevo") {
                        Task { await scanDuplicates() }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(duplicateGroups, id: \.id) { group in
                    Section(String(format: "Duplicados - %@ ahorrables", group.savingsText)) {
                        ForEach(group.files, id: \.id) { file in
                            HStack {
                                Image(nsImage: ThumbnailService.shared.thumbnail(for: file.path))
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .cornerRadius(4)
                                
                                Text(file.name)
                                
                                Spacer()
                                
                                Text(file.sizeText)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var appCachesList: some View {
        Group {
            if appCaches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.purple)
                    
                    Text("No hay caches")
                        .bold()
                    
                    Text("Todo limpio por ahora")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Escanear de nuevo") {
                        Task { await scanAppCaches() }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appCaches, id: \.id) { app in
                    HStack {
                        Image(nsImage: ThumbnailService.shared.thumbnail(for: app.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)
                        
                        VStack(alignment: .leading) {
                            Text(app.appName)
                                .bold()
                            Text(app.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.2f MB", app.sizeMB))
                            .bold()
                        
                        Button("Borrar") {
                            deleteAppCache(app)
                        }
                        .tint(.red)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    var deepCleanList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                
                ForEach(profileItems, id: \.id) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .bold()
                            Text(item.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(String(format: "%.2f GB", item.sizeMB / 1024.0))
                                .bold()
                            
                            Button("Borrar") {
                                deleteDeepItem(item)
                            }
                            .tint(.red)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    
                    Divider()
                        .opacity(0.2)
                }
                
                ForEach(deepCleanItems, id: \.id) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .bold()
                            Text(item.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.0f MB", item.sizeMB))
                            .bold()
                        
                        Button("Borrar") {
                            deleteDeepItem(item)
                        }
                        .tint(.red)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                }
            }
        }
    }
    
    // MARK: - Scanning - SEGURO Y SECUENCIAL
    
    func initialScan() async {
        isScanning = true
        
        // Detectar perfil primero
        do {
            proInfo = try ProDetectionResult.detect()
            
            if let pro = proInfo {
                selectedProfile = ProfileService.shared.detectProfile(from: pro)
                
                let subs = ProfileService.shared.detectSubProfiles(from: pro)
                
                if !subs.isEmpty {
                    selectedSubProfiles = Set(subs)
                }
            }
        } catch {
            print("[ContentView] Error detectando perfil: \(error)")
        }
        
        // Escaneo SECUENCIAL, no concurrente
        // Así no satura el SSD
        await scanFiles()
        await scanProfile()
        await scanDeep()
        await scanDuplicates()
        await scanAppCaches()
        
        isScanning = false
        
        totalGB = (files.reduce(0) { $0 + $1.sizeMB } + extendedFiles.reduce(0) { $0 + $1.sizeMB }) / 1024.0
        profileTotalGB = profileItems.reduce(0) { $0 + $1.sizeMB } / 1024.0
        
        dashboard.updateHealth(totalGB: totalGB)
        
        print("[ContentView] initialScan terminado: \(totalGB)GB archivos, \(profileTotalGB)GB dev")
    }
    
    func scanAll() async {
        isScanning = true
        
        await scanFiles()
        await scanProfile()
        await scanDeep()
        await scanDuplicates()
        await scanAppCaches()
        
        isScanning = false
        
        totalGB = (files.reduce(0) { $0 + $1.sizeMB } + extendedFiles.reduce(0) { $0 + $1.sizeMB }) / 1024.0
        profileTotalGB = profileItems.reduce(0) { $0 + $1.sizeMB } / 1024.0
        
        dashboard.updateHealth(totalGB: totalGB)
        menuBar.update(totalGB: totalGB + profileTotalGB)
        
        print("[ContentView] scanAll terminado")
    }
    
    func scanFiles() async {
        do {
            let downloads = try ScannerService.shared.scanDownloads()
            let extended = try ExtendedScannerService.shared.scanExtended()
            
            await MainActor.run {
                self.files = downloads
                self.extendedFiles = extended
            }
        } catch {
            print("[ContentView] Error scanFiles: \(error)")
        }
    }
    
    func scanProfile() async {
        let items = ProfileService.shared.scanForProfile(selectedProfile, subProfiles: Array(selectedSubProfiles))
        
        await MainActor.run {
            self.profileItems = items
            self.profileTotalGB = items.reduce(0) { $0 + $1.sizeMB } / 1024.0
        }
    }
    
    func scanDeep() async {
        let items = DeepCleanService.shared.scanDeepClean()
        
        await MainActor.run {
            self.deepCleanItems = items
        }
    }
    
    func scanDuplicates() async {
        let groups = DuplicateService.shared.findDuplicates(
            in: ScannerService.realHomeDirectory.appendingPathComponent("Downloads").path
        )
        
        await MainActor.run {
            self.duplicateGroups = groups
        }
    }
    
    func scanAppCaches() async {
        let caches = AppCacheService.shared.scanAppCaches()
        
        await MainActor.run {
            self.appCaches = caches
        }
    }
    
    // MARK: - Delete - SEGURO
    
    func deleteFile(_ file: FileItem) {
        
        // Seguridad: verificar path
        guard file.path.hasPrefix("/Users/") else {
            print("[Security] Intento de borrar path no seguro: \(file.path)")
            return
        }
        
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
            
            dashboard.trackClean(freedMB: file.sizeMB, type: "file")
            
            files.removeAll { $0.id == file.id }
            extendedFiles.removeAll { $0.id == file.id }
            
            print("[Delete] Archivo movido a papelera: \(file.path)")
            
        } catch {
            print("[Delete] Error borrando \(file.path): \(error)")
        }
    }
    
    func deleteAppCache(_ app: AppCacheInfo) {
        
        // Seguridad: debe estar en Caches
        guard app.path.contains("/Library/Caches/") else {
            print("[Security] Path no seguro para app cache: \(app.path)")
            return
        }
        
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
            
            dashboard.trackClean(freedMB: app.sizeMB, type: "appCache")
            
            appCaches.removeAll { $0.id == app.id }
            
            print("[Delete] Cache movido a papelera: \(app.path)")
            
        } catch {
            print("[Delete] Error borrando cache \(app.path): \(error)")
        }
    }
    
    func deleteDeepItem(_ item: DeepCleanItem) {
        
        do {
            try DeepCleanService.shared.delete(item: item)
            
            dashboard.trackClean(freedMB: item.sizeMB, type: "deep")
            
            profileItems.removeAll { $0.id == item.id }
            deepCleanItems.removeAll { $0.id == item.id }
            
            profileTotalGB = profileItems.reduce(0) { $0 + $1.sizeMB } / 1024.0
            
            print("[Delete] Deep item borrado: \(item.path)")
            
        } catch {
            print("[Delete] Error borrando deep item \(item.path): \(error)")
        }
    }
}
