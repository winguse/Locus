//
//  AppDelegate.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import SwiftUI
import CoreLocation
import CoreData
import OSLog
import UserNotifications
import UserNotificationsUI

class AppDelegate: NSObject, UIApplicationDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
  
  private let locationManager = CLLocationManager()
  private var onHighAccuateMonitor = false
  private var lastLocation: CLLocation? = nil
  private var stationLocation: CLLocation? = nil
  
  
  func startLocationService() {
    locationManager.delegate = self
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.requestAlwaysAuthorization()
    startHighAccuateMonitor()
  }
  
  private func startHighAccuateMonitor() {
    if onHighAccuateMonitor {
      return
    }
    onHighAccuateMonitor = true
    locationManager.stopMonitoringSignificantLocationChanges()
    
    let defaults = UserDefaults.standard
    if defaults.string(forKey: "accuracy") == "best" {
      locationManager.desiredAccuracy = kCLLocationAccuracyBest
      locationManager.distanceFilter = kCLDistanceFilterNone
      Utils.sendNotification(title: "Monitor accuate changed", body: "High best")
    } else {
      let accuracy = defaults.double(forKey: "accuracy")
      locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
      locationManager.distanceFilter = accuracy
      Utils.sendNotification(title: "Monitor accuate changed", body: "High \(accuracy)m")
    }
    
    Logger.background.notice("start high accuate monitor")
    // high accuate
    locationManager.activityType = .other
    locationManager.pausesLocationUpdatesAutomatically = true
    locationManager.startUpdatingLocation()
  }
  
  private func startLowAccuateMonitor() {
    if !onHighAccuateMonitor {
      return
    }
    onHighAccuateMonitor = false
    Logger.background.notice("start low accuate monitor")
    Utils.sendNotification(title: "Monitor accuate changed", body: "Low")
    locationManager.stopUpdatingLocation()
    // low accuate
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.startMonitoringSignificantLocationChanges()
  }
  
  func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
    startLowAccuateMonitor()
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Logger.background.error("location manager error: \(error as NSObject)")
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if !onHighAccuateMonitor {
      startHighAccuateMonitor()
    }
    if let current = locations.last {
      if (current.speed < 1 && current.speedAccuracy >= 0 && current.speedAccuracy < 10) {
        if (stationLocation == nil) {
          stationLocation = current
        } else if (stationLocation!.timestamp.distance(to: current.timestamp) > 60) { // one minute
          startLowAccuateMonitor()
        }
      } else {
        stationLocation = nil
      }
      
      if (lastLocation == nil || (
        current.timestamp >= lastLocation!.timestamp.addingTimeInterval(10)
        && (current.distance(from: lastLocation!) >= current.horizontalAccuracy + lastLocation!.horizontalAccuracy || current.horizontalAccuracy < lastLocation!.horizontalAccuracy)
      )) {
        Logger.background.debug("add new point \(current.coordinate.latitude), \(current.coordinate.longitude)")
        lastLocation = current
        PersistenceController.shared.saveLocation(current)
      }
    }
  }
  
  
  func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    return true
  }
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    Logger.background.info("start app")
    Utils.hook()
    startLocationService()
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        Logger.background.error("request for notification error \(error as NSObject)")
      }
    }
    center.delegate = self
    return true
  }
  
  func applicationDidEnterBackground(_ application: UIApplication) {
    Logger.background.notice("enter background")
    Utils.sendNotification(title: "Entered background", body: "")
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    Logger.background.notice("become active")
  }
  
  func applicationWillResignActive(_ application: UIApplication) {
    Logger.background.notice("resign active")
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner])
  }
}

