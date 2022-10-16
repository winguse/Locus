//
//  Persistence.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import CoreData
import OSLog
import CoreLocation

struct PersistenceController {
  static let shared = PersistenceController()

  static var preview: PersistenceController = {
    let result = PersistenceController(inMemory: true)
    let viewContext = result.container.viewContext
    let minTime = Date()
    let longitude = -122.0267635
    let latitude = 37.3842192
    let delta = 0.01
    for i in 0..<10 {
      let location = Location(context: viewContext)
      location.latitude = latitude + delta * Double(i)
      location.longitude = longitude + delta * Double(i)
      location.timestamp = minTime.addingTimeInterval(TimeInterval(i))
    }
    do {
      try viewContext.save()
    } catch {
      // Replace this implementation with code to handle the error appropriately.
      // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
      let nsError = error as NSError
      fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
    }
    return result
  }()

  let container: NSPersistentCloudKitContainer

  init(inMemory: Bool = false) {
    container = NSPersistentCloudKitContainer(name: "Locus")
    if inMemory {
      container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
    }
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

        /*
         Typical reasons for an error here include:
         * The parent directory does not exist, cannot be created, or disallows writing.
         * The persistent store is not accessible, due to permissions or data protection when the device is locked.
         * The device is out of space.
         * The store could not be migrated to the current model version.
         Check the error message to determine what the actual problem was.
         */
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })
    container.viewContext.automaticallyMergesChangesFromParent = true
  }

  func saveLocation(_ clLocation: CLLocation) {
    let ctx = container.viewContext
    let newLocation = Location(context: ctx)
    newLocation.timestamp = clLocation.timestamp
    newLocation.latitude = clLocation.coordinate.latitude
    newLocation.longitude = clLocation.coordinate.longitude
    newLocation.altitude = clLocation.altitude
    newLocation.speed = clLocation.speed
    newLocation.course = clLocation.course
    newLocation.horizontalAccuracy = clLocation.horizontalAccuracy
    newLocation.verticalAccuracy = clLocation.verticalAccuracy
    newLocation.speedAccuracy = clLocation.speedAccuracy
    do {
      try ctx.save()
    } catch {
      let nsError = error as NSError
      Logger.background.critical("Error found when trying to save location \(nsError), \(nsError.userInfo)")
    }
  }

  func queryLocations(start: Date, end: Date) -> [Location] {
    let ctx = container.viewContext
    let fetchRequest = NSFetchRequest<Location>(
      entityName: "Location"
    )
    fetchRequest.predicate = NSCompoundPredicate(
      andPredicateWithSubpredicates: [
        NSPredicate.init(format: "timestamp >= %@", start as NSDate),
        NSPredicate.init(format: "timestamp < %@", end as NSDate),
      ])
    do {
      return try ctx.fetch(fetchRequest)
    } catch {
      let nsError = error as NSError
      Logger.background.critical("Error found when trying to fetch locations \(nsError), \(nsError.userInfo)")
    }
    return [Location]()
  }

  func query(forFunction: String) -> Date? {
    let ctx = container.viewContext
    let request = NSFetchRequest<NSFetchRequestResult>(
      entityName: "Location"
    )
    request.resultType = NSFetchRequestResultType.dictionaryResultType
    let keypathExpression = NSExpression(forKeyPath: "timestamp")
    let expression = NSExpression(forFunction: forFunction, arguments: [keypathExpression])
    let outputKey = "result"
    let expressionDescription = NSExpressionDescription()
    expressionDescription.name = outputKey
    expressionDescription.expression = expression
    expressionDescription.expressionResultType = .dateAttributeType
    request.propertiesToFetch = [expressionDescription]
    do {
      if let result = try ctx.fetch(request) as? [[String: Date]],
         let dict = result.first,
         let minDate = dict[outputKey] {
        Logger.background.debug("Find \(forFunction) timestamp \(minDate)")
        return minDate
      }
      Logger.background.warning("Cannot find \(forFunction) timestamp")
    } catch {
      let nsError = error as NSError
      Logger.background.critical("Error found when trying to fetch \(forFunction) timestamp \(nsError), \(nsError.userInfo)")
    }
    return nil
  }

  func queryMinTimestamp() -> Date {
    return query(forFunction: "min:") ?? Date.init(timeIntervalSince1970: 0)
  }

  func queryMaxTimestamp() -> Date? {
    return query(forFunction: "max:")
  }
}
