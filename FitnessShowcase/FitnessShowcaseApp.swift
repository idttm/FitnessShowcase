//
//  FitnessShowcaseApp.swift
//  FitnessShowcase
//
//  Created by Andrew Cheberyako on 26.07.2025.
//

import SwiftUI

@main
struct FitnessShowcaseApp: App {
    @StateObject private var liveVM = LiveStreamViewModel()
    
    var body: some Scene {
        WindowGroup {
            IOSDashboardView()
                .environmentObject(liveVM)
        }
    }
}
