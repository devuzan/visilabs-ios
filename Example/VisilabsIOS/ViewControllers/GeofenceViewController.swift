//
//  GeofenceViewController.swift
//  VisilabsIOS_Example
//
//  Created by Egemen on 22.06.2020.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import Eureka
import CleanyModal
import VisilabsIOS


class GeofenceViewController: FormViewController {
    
    let lastFetchTime = "Last Fetch Time"
    let lastKnownLatitude = "Last Known Latitude"
    let lastKnownLongitude = "Last Known Longitude"
    
    let dateFormatter = DateFormatter()
    var visilabsGeofenceHistory: VisilabsGeofenceHistory!
    var formattedDateKeyFetchHistory = [String: [VisilabsGeofenceEntity]]()
    var historySection = Section("Geofence Server Checks".uppercased(with: Locale(identifier: "en_US")))
    var errorSection = Section("Geofence Server Checks With Error".uppercased(with: Locale(identifier: "en_US")))
    var refreshSection = Section()
    var lastFetchTimeRow : TextRow!
    var lastKnownLatitudeRow : TextRow!
    var lastKnownLongitudeRow : TextRow!

    override func viewDidLoad() {
        super.viewDidLoad()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        initializeForm()
    }
    
    private func initializeForm() {
        refreshSection.append(ButtonRow() {
            $0.title = "Refresh"
        }
        .onCellSelection { cell, row in
            self.refreshData()
        })
        lastFetchTimeRow = TextRow(lastFetchTime) {
            $0.title = lastFetchTime
            $0.disabled = true
        }
        lastKnownLatitudeRow = TextRow(lastKnownLatitude) {
            $0.title = lastKnownLatitude
            $0.disabled = true
        }
        lastKnownLongitudeRow = TextRow(lastKnownLongitude) {
            $0.title = lastKnownLongitude
            $0.disabled = true
        }
        
        refreshSection.append(lastFetchTimeRow)
        refreshSection.append(lastKnownLatitudeRow)
        refreshSection.append(lastKnownLongitudeRow)
        
        form.append(refreshSection)
        form.append(historySection)
        form.append(errorSection)
        refreshData()
    }
        
    private func refreshData(){
        visilabsGeofenceHistory = VisilabsDataManager.readVisilabsGeofenceHistory()
        lastFetchTimeRow.value = dateFormatter.string(from: visilabsGeofenceHistory.lastFetchTime ?? Date(timeIntervalSince1970: 0))
        lastKnownLatitudeRow.value = String(format: "%.013f", visilabsGeofenceHistory.lastKnownLatitude ?? 0.0)
        lastKnownLongitudeRow.value = String(format: "%.013f", visilabsGeofenceHistory.lastKnownLongitude ?? 0.0)
        refreshSection.reload()
        
        historySection.removeAll()
        formattedDateKeyFetchHistory.removeAll()
        
        
        for date in visilabsGeofenceHistory.fetchHistory.keys.sorted(by:>) {
            let formattedDate = dateFormatter.string(from: date)
            formattedDateKeyFetchHistory[formattedDate] = visilabsGeofenceHistory.fetchHistory[date]
            
            historySection.append(ButtonRow() {
                $0.title = formattedDate
            }
            .onCellSelection { cell, row in
                let alert = GeofenceAlertViewController(formattedDate: row.title!, visilabsGeofenceEntities: self.formattedDateKeyFetchHistory[row.title!])
                alert.addAction(title: "Dismiss", style: .default)
                self.present(alert, animated: true, completion: nil)
            })
        }
        
    }
}

class GeofenceAlertViewController: CleanyAlertViewController {
    
    init(formattedDate: String, visilabsGeofenceEntities: [VisilabsGeofenceEntity]?) {
        let styleSettings = CleanyAlertConfig.getDefaultStyleSettings()
        styleSettings[.cornerRadius] = 18
        var message = "There is no data"
        if let geofences = visilabsGeofenceEntities, geofences.count > 0 {
            message = GeofenceAlertViewController.getMessageFromGeofenceEntities(geofences)
        }
        super.init(title: formattedDate, message: message, preferredStyle: .alert, styleSettings: styleSettings)
    }
    
    private static func getMessageFromGeofenceEntities(_ geofences: [VisilabsGeofenceEntity]) -> String{
        var message = ""
        for geofence in geofences {
            message = message + "actid:\(geofence.actId) geoid\(geofence.geofenceId)" +  "\n"
        }
        return message
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
