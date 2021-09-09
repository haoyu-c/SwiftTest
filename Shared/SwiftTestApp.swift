//
//  SwiftTestApp.swift
//  Shared
//
//  Created by chenhaoyu.1999 on 2021/8/28.
//

import SwiftUI

@main
struct SwiftTestApp: App {
    init() {
        Task.detached(priority: .userInitiated) {
            await CustomActor().test()
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
