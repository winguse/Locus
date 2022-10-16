//
//  Logger.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import SwiftUI
import OSLog

extension Logger {
  private static var subsystem = Bundle.main.bundleIdentifier!
  static let background = Logger(subsystem: subsystem, category: "background")
  static let ui = Logger(subsystem: subsystem, category: "ui")
}

