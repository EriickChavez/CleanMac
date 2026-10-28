//
//  HomeView.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI
struct HomeView: View {
    @ObservedObject var dashboard: DashboardService; var onScan: ()->Void; var totalGB: Double; var profileItems: [DeepCleanItem]
    var body: some View {
        ScrollView{ VStack(alignment:.leading,spacing:20){
            HStack(spacing:16){
                StatCard(title:"Total Liberado",value:String(format:"%.2f GB",dashboard.totalFreedMB/1024),icon:"externaldrive.fill",color:.green)
                StatCard(title:"Salud Mac",value:"\(dashboard.healthScore)%",icon:"heart.fill",color:.red)
                StatCard(title:"Limpiezas",value:"\(dashboard.cleanCount)",icon:"checkmark.circle.fill",color:.blue)
            }
            Text("Historial").bold()
            ForEach(dashboard.history.prefix(10)){ ev in HStack{ Text(ev.type); Spacer(); Text(String(format:"%.1f MB",ev.freedMB)) }.padding(8).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 8)) }
            Button("Escanear ahora"){ onScan() }.buttonStyle(.borderedProminent).tint(.purple)
        }.padding(20)}
    }
}
struct StatCard: View { var title:String; var value:String; var icon:String; var color:Color; var body: some View{ VStack(alignment:.leading){ Label(title,systemImage:icon).font(.caption).foregroundColor(.secondary); Text(value).font(.title2).bold() }.padding().frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12)) } }
