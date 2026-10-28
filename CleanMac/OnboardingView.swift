//
//  OnboardingView.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool; @State private var step=0; @State private var potentialGB:Double=0
    var body: some View {
        ZStack{ Color(red:0.11,green:0.11,blue:0.16).ignoresSafeArea(); VStack(spacing: 32){
            HStack(spacing:8){ ForEach(0..<3){ i in Circle().fill(i==step ? Color.purple : Color.white.opacity(0.2)).frame(width: 8, height: 8) } }.padding(.top,40)
            Spacer(); Group{ switch step { case 0: VStack(spacing:20){ Image(systemName:"sparkles.rectangle.stack.fill").font(.system(size:64)).foregroundColor(.purple); Text("Bienvenido a Clear").font(.system(size:28,weight:.bold)).foregroundColor(.white); Text("Tu Mac acumula hasta 40GB de basura invisible").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7)).padding(.horizontal,60) }; case 1: VStack(spacing:20){ Image(systemName:"lock.shield.fill").font(.system(size:64)).foregroundColor(.green); Text("100% privado").font(.system(size:28,weight:.bold)).foregroundColor(.white); Text("Todo local. No tocamos node_modules, .git, Pods.").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7)).padding(.horizontal,60) }; default: VStack(spacing:20){ Image(systemName:"hammer.fill").font(.system(size:64)).foregroundColor(.orange); Text("Listo para limpiar").font(.system(size:28,weight:.bold)).foregroundColor(.white); Text("Detectamos tu perfil Developer automáticamente.").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7)).padding(.horizontal,60) } }; Spacer()
                HStack{ if step>0{ Button("Atrás"){ withAnimation{step-=1} }.buttonStyle(.plain).foregroundColor(.white.opacity(0.6)) }; Spacer(); Button(step==2 ? "Empezar" : "Siguiente"){ if step==2{ hasSeenOnboarding=true; UserDefaults.standard.set(true,forKey:"hasSeenOnboarding") } else { withAnimation{step+=1} } }.buttonStyle(.borderedProminent).tint(.purple) }.padding(.horizontal,40).padding(.bottom,40)
            }}.frame(width:600,height:500)
        }
    }
}
