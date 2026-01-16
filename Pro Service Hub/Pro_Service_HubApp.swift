//
//  Pro_Service_HubApp.swift
//  Pro Service Hub
//
//  Created by James Ostrowick on 2026/01/06.
//

import SwiftUI

@main
struct Pro_Service_HubApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootTabView(session: session)
                .environmentObject(session)
        }
    }
}
