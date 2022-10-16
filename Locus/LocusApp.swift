//
//  LocusApp.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import SwiftUI

@main
struct LocusApp: App {
  let persistenceController = PersistenceController.shared
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
  } 
}
