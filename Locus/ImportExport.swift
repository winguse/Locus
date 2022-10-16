//
//  ImportExport.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import SwiftUI
import CoreData
import OSLog

class ImportExport {
  
  static let mgr = FileManager.default
  static let root = mgr.urls(for: .documentDirectory, in: .userDomainMask).first!
  
  static let requireHeaderCount = 3
  static let headers = ["timestamp", "latitude", "longitude", "altitude", "speed", "course", "horizontalAccuracy", "verticalAccuracy", "speedAccuracy"]
  
  /// this is a function to export daily data, base on current calendar
  /// for the last day data, always override existing file
  /// or, don't override
  static func exportData(override: Bool = false) {
    PersistenceController.shared.container.performBackgroundTask { (ctx) in
      
      let pc = PersistenceController.shared
      let calendar = Calendar.current
      let oneDay = 3600 * 24.0
      let endTime = Date.init(timeIntervalSinceNow: 0)
      let dateFolderFmt = DateFormatter()
      dateFolderFmt.dateFormat = "yyyy/MM"
      let dateFileNameFmt = DateFormatter()
      dateFileNameFmt.dateFormat = "yyyy-MM-dd"
      
      let headerRow = headers.joined(separator: ",")
      var currentTime = calendar.date(from: calendar.dateComponents([.day, .month, .year], from: pc.queryMinTimestamp()))!
      while currentTime < endTime {
        let folder = root.appendingPathComponent("export/\(dateFolderFmt.string(from: currentTime))")
        if !mgr.fileExists(atPath: folder.path, isDirectory: nil) {
          do {
            try mgr.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
          } catch {
            Logger.background.error("FAIL: create folder \(folder.path) error \(error as NSObject)")
            return
          }
        }
        
        let file = folder.appendingPathComponent("\(dateFileNameFmt.string(from: currentTime)).csv")
        let nextTime = currentTime.addingTimeInterval(oneDay)
        
        if (override || nextTime > endTime || !mgr.fileExists(atPath: file.path)) {
          var content = headerRow
          for location in pc.queryLocations(start: currentTime, end: nextTime) { // we collect data points every 10 seconds, so a day will at most ~8K row, which memory should be ok
            content += "\n\(location.timestamp!.timeIntervalSince1970),\(location.latitude),\(location.longitude),\(location.altitude),\(location.speed),\(location.course),\(location.horizontalAccuracy),\(location.verticalAccuracy),\(location.speedAccuracy)"
          }
          
          do {
            try content.write(to: file, atomically: true, encoding: String.Encoding.utf8)
          } catch {
            Logger.background.error("FAIL: write file \(file.path) error \(error as NSObject)")
            return
          }
        }
        currentTime = nextTime
      }
      
      Logger.background.notice("SUCCESS")
    }
  }
  
  static func importData(override: Bool = true) {
    PersistenceController.shared.container.performBackgroundTask { (ctx) in
      let folder = root.appendingPathComponent("import")
      if !mgr.fileExists(atPath: folder.path, isDirectory: nil) {
        do {
          try mgr.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        } catch {
          Logger.background.error("FAIL: create folder \(folder.path) error \(error as NSObject)")
          return
        }
      }
      do {
        var files = [String]()
        if let enumerator = mgr.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
          for case let fileURL as URL in enumerator {
            do {
              let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
              if fileAttributes.isRegularFile! {
                files.append(fileURL.path)
              }
            } catch {
              Logger.background.error("FAIL: error was found when listing import files")
              return
            }
          }
        }
        for file in files {
          if (!file.hasSuffix(".csv")) {
            continue
          }
          let content = try String(contentsOfFile: file)
          
          let lines = content.split(separator: "\n")
          
          let headerRow = lines[0]
          let inputHeaders = headerRow.split(separator: ",")
          var headerMap = [String: Int]()
          for idx in 0..<inputHeaders.count {
            headerMap[String(inputHeaders[idx])] = idx
          }
          for idx in 0..<requireHeaderCount {
            if (headerMap[headers[idx]] == nil) {
              Logger.background.error("FAIL: \(file) doesn't contains required field \(headers[idx])")
              return
            }
          }
          let headerId2ColumnIdx = headers.map { headerMap[$0] }
          var matrix = Array.init(repeating: Array<Double?>.init(repeating: nil, count: headers.count), count: lines.count - 1)
          for lineIdx in 1..<lines.count {
            let line = lines[lineIdx]
            let columns = line.split(separator: ",")
            for headerId in 0..<headerId2ColumnIdx.count {
              if let nonNilColumnIdx = headerId2ColumnIdx[headerId] {
                let value = Double(columns[nonNilColumnIdx])
                if (nonNilColumnIdx < requireHeaderCount && value == nil) {
                  Logger.background.error("FAIL: \(file) contains line #\(lineIdx + 1): '\(line)', doesn't have required number value of \(headers[headerId])")
                  return
                }
                matrix[lineIdx - 1][headerId] = value
              }
            }
          }
          
          if (matrix.count == 0) {
            continue
          }
          
          if (override) {
            let allTs = matrix.map { $0[0]! }
            let start = Date.init(timeIntervalSince1970: allTs.min()!)
            let end = Date.init(timeIntervalSince1970: allTs.max()!)
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(
              entityName: "Location"
            )
            fetchRequest.predicate = NSCompoundPredicate(
              andPredicateWithSubpredicates: [
                NSPredicate.init(format: "timestamp >= %@", start as NSDate),
                NSPredicate.init(format: "timestamp <= %@", end as NSDate),
              ])
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
              try ctx.execute(deleteRequest)
            } catch {
              let nsError = error as NSError
              Logger.background.critical("Error found when trying to delete locations \(nsError), \(nsError.userInfo)")
            }
          }
          for row in matrix {
            let newLocation = Location(context: ctx)
            newLocation.timestamp = Date.init(timeIntervalSince1970: row[0]!)
            newLocation.latitude = row[1]!
            newLocation.longitude = row[2]!
            newLocation.altitude = row[3] ?? -1
            newLocation.speed = row[4] ?? -1
            newLocation.course = row[5] ?? -1
            newLocation.horizontalAccuracy = row[6] ?? -1
            newLocation.verticalAccuracy = row[7] ?? -1
            newLocation.speedAccuracy = row[8] ?? -1
          }
          do {
            try ctx.save()
            Utils.sendNotification(title: "Import", body: "saved \(matrix.count) location points to \(file)")
          } catch {
            let nsError = error as NSError
            Logger.background.error("Error found when trying to save location \(nsError), \(nsError.userInfo)")
            return
          }
        }
      } catch {
        Logger.background.error("FAIL: import failed with error \(error as NSObject)")
        return
      }
      Logger.background.notice("SUCCESS")
    }
  }
}

