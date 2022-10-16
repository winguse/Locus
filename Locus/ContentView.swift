//
//  ContentView.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import SwiftUI
import OSLog

struct ContentView: View {
  private let basicSize: CGFloat = 100

  enum DisplayMode: String {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
  }

  @EnvironmentObject var store: LifePathStore

  @State private var previousDisabled = false
  @State private var nextDisabled = false
  @State private var showPopover = false
  @State private var displayMode: DisplayMode = .daily
  @State private var selectedStartTime: Date = Date()

  var body: some View {
    ZStack {
      MapView(locations: $store.locations)
        .edgesIgnoringSafeArea(.all)
      VStack {
        Spacer().frame(maxWidth: .infinity)
        ZStack {
          HStack {
            Button(action: { update(direction: -1) }, label: {
              Image(systemName: "arrowshape.turn.up.left.fill")
                .padding(.trailing, basicSize * 0.5)
                .frame(width: basicSize * 1.1, height: basicSize * 0.5)
            })
            .foregroundColor(previousDisabled ? Color.gray : Color.blue)
            .background(Color.white)
            .cornerRadius(basicSize * 0.25)
            .disabled(previousDisabled)
            Button(action: { update(direction: 1) }, label: {
              Image(systemName: "arrowshape.turn.up.right.fill")
                .padding(.leading, basicSize * 0.5)
                .frame(width: basicSize * 1.1, height: basicSize * 0.5)
            })
            .foregroundColor(nextDisabled ? Color.gray : Color.blue)
            .background(Color.white)
            .cornerRadius(basicSize * 0.25)
            .disabled(nextDisabled)
          }
          Button(action: togglePopover, label: {
            VStack {
              Text("\(displayMode.rawValue)")
              Text(renderDateDisplayString())
                .font(.footnote)
                .fontWeight(.thin)

            }
            .frame(width: basicSize, height: basicSize)
            .foregroundColor(Color.white)
          })
          .background(Color.blue)
          .clipShape(Circle())
        }
        .shadow(radius: 3, x: 2, y: 2)
        .padding(.bottom, basicSize * 0.5)
      }
    }.popover(isPresented: self.$showPopover) {
      VStack {
        Picker("", selection: $displayMode) {
          Text(DisplayMode.daily.rawValue).tag(DisplayMode.daily)
          Text(DisplayMode.weekly.rawValue).tag(DisplayMode.weekly)
          Text(DisplayMode.monthly.rawValue).tag(DisplayMode.monthly)
        }
        .pickerStyle(SegmentedPickerStyle())
        DatePicker("Time", selection: $selectedStartTime, in: store.minTimestatmp...Date(), displayedComponents: .date)
          .datePickerStyle(GraphicalDatePickerStyle())
        HStack {
          Spacer()
          Button(action: { ImportExport.exportData() }, label: {
            Text("Export").frame(width: basicSize, height: basicSize * 0.4)
          })
          .foregroundColor(Color.primary)
          .background(Color.secondary)
          .cornerRadius(basicSize * 0.1)
          Spacer()
          Button(action: { ImportExport.importData() }, label: {
            Text("Import").frame(width: basicSize, height: basicSize * 0.4)
          })
          .foregroundColor(Color.primary)
          .background(Color.secondary)
          .cornerRadius(basicSize * 0.1)
          Spacer()
        }
        Spacer().frame(maxWidth: .infinity)
        Button(action: togglePopover, label: {
          Text("OK")
            .frame(width: basicSize * 2, height: basicSize * 0.4)
        })
        .foregroundColor(Color.white)
        .background(Color.blue)
        .cornerRadius(basicSize * 0.1)

      }
      .padding(.all, 0.2 * basicSize)
      .padding(.bottom, 0.3 * basicSize)
    } .onAppear(perform: {
      update(direction: 0)
    })
  }

  private func renderDateDisplayString() -> String {
    switch displayMode {
      case .daily:
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .none
        return dateFmt.string(from: selectedStartTime)
      case .weekly:
        let weekOfMonth = NSCalendar.current.component(.weekOfMonth, from: selectedStartTime)
        let dateFmt = DateFormatter()
        dateFmt.setLocalizedDateFormatFromTemplate("yyyyMMM")
        return "\(dateFmt.string(from: selectedStartTime)) #\(weekOfMonth)"
      case .monthly:
        let dateFmt = DateFormatter()
        dateFmt.setLocalizedDateFormatFromTemplate("yyyyMMM")
        return "\(dateFmt.string(from: selectedStartTime))"
    }
  }

  private func floor(_ from: Date) -> Date {
    let calendar = Calendar.current
    switch displayMode {
      case .daily:
        return calendar.date(from: calendar.dateComponents([.day, .month, .year], from: from))!
      case .weekly:
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: from))!
      case .monthly:
        return calendar.date(from: calendar.dateComponents([.month, .year], from: from))!
    }
  }

  private func nextTime(_ direction: Int, _ to: Date) -> Date {
    if (displayMode == .monthly) {
      return Calendar.current.date(byAdding: .month, value: direction, to: to)!
    }
    return Calendar.current.date(byAdding: .day, value: direction * (displayMode == .weekly ? 7 : 1), to: to)!
  }

  private func update(direction: Int) {
    let minStartTime = floor(store.minTimestatmp)
    selectedStartTime = nextTime(direction, floor(selectedStartTime))
    if (selectedStartTime < minStartTime) {
      selectedStartTime = minStartTime
    }
    let selectedEndTime = nextTime(1, selectedStartTime)
    previousDisabled = nextTime(-1, selectedStartTime) < minStartTime
    nextDisabled = selectedEndTime > Date()
    Logger.ui.debug("query \(displayMode.rawValue) \(selectedStartTime) ~ \(selectedEndTime)")
    store.fetchLocations(start: selectedStartTime, end: selectedEndTime)
  }

  private func togglePopover() {
    self.showPopover.toggle()
    if (!self.showPopover) {
      update(direction: 0)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
        .environmentObject(LifePathStore(pc: PersistenceController.preview))
    }
  }
}
