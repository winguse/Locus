//
//  Utils.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//


import SwiftUI
import CoreLocation
import OSLog

class Utils {
  private static let a = 6378245.0;
  private static let ee = 0.00669342162296594323;

  static func transformFromWGSToGCJ(wgsLoc: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
    var adjustLoc = CLLocationCoordinate2D();
    var adjustLat = transformLat(x: wgsLoc.longitude - 105.0, y: wgsLoc.latitude - 35.0);
    var adjustLon = transformLon(x: wgsLoc.longitude - 105.0, y: wgsLoc.latitude - 35.0);
    let radLat = wgsLoc.latitude / 180.0 * Double.pi;
    var magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    let sqrtMagic = sqrt(magic);
    adjustLat = (adjustLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi);
    adjustLon = (adjustLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi);
    adjustLoc.latitude = wgsLoc.latitude + adjustLat;
    adjustLoc.longitude = wgsLoc.longitude + adjustLon;
    return adjustLoc;
  }

  private static func transformLat(x: Double, y: Double) -> Double {
    var lat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y ;
    lat += 0.2 * sqrt(fabs(x));
    lat += (20.0 * sin(6.0 * x * Double.pi)) * 2.0 / 3.0;
    lat += (20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0;
    lat += (20.0 * sin(y * Double.pi)) * 2.0 / 3.0;
    lat += (40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0;
    lat += (160.0 * sin(y / 12.0 * Double.pi)) * 2.0 / 3.0;
    lat += (320 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0;
    return lat;
  }

  private static func transformLon(x: Double, y: Double) -> Double {
    var lon = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y ;
    lon += 0.1 * sqrt(fabs(x));
    lon += (20.0 * sin(6.0 * x * Double.pi)) * 2.0 / 3.0;
    lon += (20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0;
    lon += (20.0 * sin(x * Double.pi)) * 2.0 / 3.0;
    lon += (40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0;
    lon += (150.0 * sin(x / 12.0 * Double.pi)) * 2.0 / 3.0;
    lon += (300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0;
    return lon;
  }

  static func sendNotification(title: String, body: String) {
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.getNotificationSettings { (settings) in
      if settings.authorizationStatus == .authorized {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)

        notificationCenter.add(request) { (error) in
          if let error = error {
            Logger.background.error("add notification error \(error as NSObject)")
          }
        }
      }
    }
  }

  static private let lockStateChange = "com.apple.springboard.lockstate"
  static private let lockStateComplete = "com.apple.springboard.lockcomplete"
  static private var locked = false

  static var lastHookCallTime: Date = Date()
  static var lastHookName: String = ""

  static private func lookCallback(name: String?) {
    if (name == nil) {
      return
    }
    Utils.lastHookName = name!
    Utils.lastHookCallTime = Date()
    if (name! == lockStateComplete) {
      locked = true
      return
    } else if (name! == lockStateChange) {
      if (locked) {
        locked = false
      } else {
        return
      }
    }
//    UIDevice.current.isBatteryMonitoringEnabled = true
//    UIDevice.current.batteryState = .charging
    Utils.sendNotification(title: "is locked?", body: "\(locked)")
  }

  static func hook() {
    let hookNames = [lockStateChange, lockStateComplete]
    for hookName in hookNames {
      // https://stackoverflow.com/questions/14191980/detect-screen-on-off-from-ios-service
      CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), //center
        nil, // observer
        { (center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) in
          Utils.lookCallback(name: name?.rawValue as String?)
        }, // callback
        hookName as NSString, // event name
        nil, // object
        .deliverImmediately)
    }
  }

  private static let formatter = DateComponentsFormatter()
  static func formatInterval(internval: TimeInterval?) -> String {
    if (internval == nil) {
      return ""
    }
    return formatter.string(from: internval!) ?? ""
  }
}

