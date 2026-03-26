//
//  ContentView.swift
//  TrainLog
//
//  Created by Sergey Shilyaev on 09.03.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            AppTablerIcon("map")
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
