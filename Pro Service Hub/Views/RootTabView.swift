//
//  RootTabView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

struct RootTabView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        if session.isAuthenticated {
            TabView {
                ContentView(session: session)
                    .tabItem {
                        Label("Companies", systemImage: "building.2")
                    }

                ProfileHomeView(session: session)
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
            }
        } else {
            LoginView(session: session)
        }
    }
}
