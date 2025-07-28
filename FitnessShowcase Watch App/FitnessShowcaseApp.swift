//
//  FitnessShowcaseApp.swift
//  FitnessShowcase Watch App
//
//  Created by Andrew Cheberyako on 26.07.2025.
//

import SwiftUI
import Combine

@main
struct FitnessShowcaseWatchApp: App {
    @StateObject private var wc = WatchConnectivityManager.shared
    private let vm = WorkoutViewModel(engine: makeEngine())

    var body: some Scene {
        WindowGroup {
            RootView(vm: vm)
                .environmentObject(wc)
                .onAppear { wc.activate() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var wc: WatchConnectivityManager
    @ObservedObject var vm: WorkoutViewModel

    var body: some View {
        TabView {
            WorkoutScreen(vm: vm, pendingPlan: wc.pendingPlan).tabItem { Text("Workout") }
            HistoryScreen(vm: vm).tabItem { Text("History") }
        }
        .tabViewStyle(.carousel)
    }
}
