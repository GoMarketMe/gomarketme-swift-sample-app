//
//  ContentView.swift
//  GoMarketMeSwiftSampleApp
//
//  Created by Toni Peinoit on 5/16/24.
//

import SwiftUI
import GoMarketMe

struct ContentView: View {
    
    init() {
        GoMarketMe.shared.initialize(apiKey: "API_KEY")
    }
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
