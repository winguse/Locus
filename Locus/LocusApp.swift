//
//  LocusApp.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import SwiftUI

@main
struct LocusApp: App {
  // register delegate so that we can hook the system apis
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  let persistenceController = PersistenceController.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(LocusStore())
    }
  }
}
