//
//  ContentView.swift
//  itsplanned
//
//  Created by Владислав Сизикин on 15.03.2025.
//

import SwiftUI
import Inject

struct ContentView: View {
    @ObserveInjection var inject
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .enableInjection()
    }
}

#Preview {
    ContentView()
}
