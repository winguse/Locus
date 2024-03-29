//
//  MapView.swift
//  Locus
//
//  Created by Yingyu Cheng on 10/15/22.
//

import MapKit
import OSLog
import SwiftUI

struct MapView: UIViewRepresentable {
  @Binding var locations: [Location]
  var applyCNOffsetAdjustment: Bool

  func updateUIView(_ uiView: MKMapView, context: Context) {
    for overlay in uiView.overlays {
      uiView.removeOverlay(overlay)
    }
    if locations.count > 1 {
      let line = MKPolyline(coordinates: locations.map {
        let co = CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        return applyCNOffsetAdjustment ? Utils.transformFromWGSToGCJ(wgsLoc: co) : co
      }, count: locations.count)

      Logger.ui.info("draw \(locations.count) points")

      uiView.addOverlay(line)
      uiView.setVisibleMapRect(line.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: true)
    } else {
      let region = MKCoordinateRegion(center: uiView.userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
      uiView.setRegion(region, animated: true)
    }
  }

  func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView(frame: .zero)
    mapView.delegate = context.coordinator
    mapView.showsUserLocation = true
    mapView.showsCompass = true
    mapView.isRotateEnabled = true
    return mapView
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
      if let overlay = overlay as? MKPolyline {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .blue
        renderer.lineWidth = 3.0
        renderer.alpha = 0.4
        return renderer
      }
      return MKOverlayRenderer()
    }
  }
}

struct MapView_Previews: PreviewProvider {
  static var previews: some View {
    MapView(locations: .constant([]), applyCNOffsetAdjustment: false)
  }
}
