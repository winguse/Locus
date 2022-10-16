//
//  LocusStore.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import SwiftUI

class LocusStore: ObservableObject {
  
  private let pc: PersistenceController
  
  init(pc: PersistenceController = PersistenceController.shared) {
    self.pc = pc
    minTimestatmp = pc.queryMinTimestamp()
    refreshMaxTimestamp()
  }
  
  @Published var minTimestatmp: Date = Date.init(timeIntervalSince1970: 0)
  @Published var maxTimestatmp: Date? = nil
  @Published var locations = [Location]()

  func refreshMaxTimestamp() {
    maxTimestatmp = self.pc.queryMaxTimestamp()
  }

  func fetchLocations(start: Date, end: Date) {
    let newLocations = pc.queryLocations(start: start, end: end)
    if locations.last != newLocations.last || locations.first != newLocations.first {
      locations = newLocations
    }
  }
}

