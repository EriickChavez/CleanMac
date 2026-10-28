//
//  SettingsView.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI
struct SettingsView: View {
    @AppStorage("trashExpiryDays") var expiryDays:Int=7; @AppStorage("skipNodeModules") var skipNodeModules:Bool=true
    var body: some View {
        Form{
            Section("Papelera"){ Picker("Borrar después de:", selection:$expiryDays){ Text("3 días").tag(3); Text("7 días").tag(7); Text("30 días").tag(30); Text("Nunca").tag(0) } }
            Section("Escaneo"){ Toggle("Saltar node_modules, .git, Pods", isOn:$skipNodeModules) }
            Section("Sobre"){ LabeledContent("Versión",value:"1.0.0 - Developer Beta"); Button("Reset Onboarding"){ UserDefaults.standard.set(false,forKey:"hasSeenOnboarding") } }
        }.formStyle(.grouped).frame(width:450,height:350).padding(20)
    }
}
