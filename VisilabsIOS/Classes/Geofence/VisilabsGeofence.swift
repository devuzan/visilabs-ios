//
//  VisilabsGeofence.swift
//  VisilabsIOS
//
//  Created by Egemen on 10.06.2020.
//

import Foundation
import CoreLocation

class VisilabsGeofence {

    static let sharedManager = VisilabsGeofence()

    var activeGeofenceList: [VisilabsGeofenceEntity]
    let profile: VisilabsProfile
    var geofenceHistory: VisilabsGeofenceHistory
    private var lastGeofenceFetchTime: Date
    private var lastSuccessfulGeofenceFetchTime: Date

    init?() {
        if let profile = VisilabsPersistence.readVisilabsProfile() {
            self.profile = profile
            VisilabsHelper.setEndpoints(dataSource: self.profile.dataSource)//TODO: bunu if içine almaya gerek var mı?
            self.activeGeofenceList = [VisilabsGeofenceEntity]()
            self.geofenceHistory = VisilabsPersistence.readVisilabsGeofenceHistory()
            self.lastGeofenceFetchTime = Date(timeIntervalSince1970: 0)
            self.lastSuccessfulGeofenceFetchTime = Date(timeIntervalSince1970: 0)
        } else {
            return nil
        }
    }

    var locationServicesEnabledForDevice: Bool {
        return VisilabsLocationManager.sharedManager.locationServicesEnabledForDevice
    }

    //notDetermined, restricted, denied, authorizedAlways, authorizedWhenInUse
    var locationServiceStateStatusForApplication: VisilabsCLAuthorizationStatus {
        return VisilabsCLAuthorizationStatus(rawValue: VisilabsLocationManager.sharedManager.locationServiceStateStatus.rawValue) ?? .none
    }

    private var locationServiceEnabledForApplication: Bool {
        return self.locationServiceStateStatusForApplication == .authorizedAlways || self.locationServiceStateStatusForApplication == .authorizedWhenInUse
    }

    func startGeofencing() {
        VisilabsLocationManager.sharedManager.createLocationManager()
    }

    private func startMonitorGeofences(geofences: [VisilabsGeofenceEntity]) {
        VisilabsLocationManager.sharedManager.stopMonitorRegions()
        self.activeGeofenceList = sortAndTakeVisilabsGeofenceEntitiesToMonitor(geofences)
        if self.profile.geofenceEnabled && self.locationServicesEnabledForDevice && self.locationServiceEnabledForApplication {
            for geofence in self.activeGeofenceList {
                let geoRegion = CLCircularRegion(center: CLLocationCoordinate2DMake(geofence.latitude, geofence.longitude), radius: geofence.radius, identifier: geofence.identifier)
                VisilabsLocationManager.sharedManager.startMonitorRegion(region: geoRegion)
            }
        }
    }

    private func sortAndTakeVisilabsGeofenceEntitiesToMonitor(_ geofences: [VisilabsGeofenceEntity]) -> [VisilabsGeofenceEntity] {
        let geofencesSortedAscending = geofences.sorted { (first, second) -> Bool in
            let firstDistance = first.distanceFromCurrentLastKnownLocation ?? Double.greatestFiniteMagnitude
            let secondDistance = second.distanceFromCurrentLastKnownLocation ?? Double.greatestFiniteMagnitude
            return firstDistance < secondDistance
        }
        var geofencesToMonitor = [VisilabsGeofenceEntity]()
        for geofence in geofencesSortedAscending {
            if geofencesToMonitor.count == self.profile.maxGeofenceCount {
                break
            }
            geofencesToMonitor.append(geofence)
        }
        return [VisilabsGeofenceEntity](geofencesToMonitor)
    }

    func getGeofenceList(lastKnownLatitude: Double?, lastKnownLongitude: Double?) {
        if self.profile.geofenceEnabled && self.locationServicesEnabledForDevice && self.locationServiceEnabledForApplication {

            let now = Date()
            let timeInterval = now.timeIntervalSince1970 - self.lastGeofenceFetchTime.timeIntervalSince1970
            if timeInterval < VisilabsConstants.GEOFENCE_FETCH_TIME_INTERVAL {
                return
            }

            self.lastGeofenceFetchTime = now
            let user = VisilabsPersistence.unarchiveUser()
            let geofenceHistory = VisilabsPersistence.readVisilabsGeofenceHistory()
            var props = [String: String]()
            props[VisilabsConstants.ORGANIZATIONID_KEY] = profile.organizationId
            props[VisilabsConstants.PROFILEID_KEY] = profile.profileId
            props[VisilabsConstants.COOKIEID_KEY] = user.cookieId
            props[VisilabsConstants.EXVISITORID_KEY] = user.exVisitorId
            props[VisilabsConstants.ACT_KEY] = VisilabsConstants.GET_LIST
            props[VisilabsConstants.TOKENID_KEY] = user.tokenId
            props[VisilabsConstants.APPID_KEY] = user.appId
            if let lat = lastKnownLatitude, let lon = lastKnownLongitude {
                props[VisilabsConstants.LATITUDE_KEY] = String(format: "%.013f", lat)
                props[VisilabsConstants.LONGITUDE_KEY] = String(format: "%.013f", lon)
            } else if let lat = geofenceHistory.lastKnownLatitude, let lon = geofenceHistory.lastKnownLongitude {
                props[VisilabsConstants.LATITUDE_KEY] = String(format: "%.013f", lat)
                props[VisilabsConstants.LONGITUDE_KEY] = String(format: "%.013f", lon)
            }

            for (key, value) in VisilabsPersistence.readTargetParameters() {
               if !key.isEmptyOrWhitespace && !value.isEmptyOrWhitespace && props[key] == nil {
                   props[key] = value
               }
            }

            VisilabsRequest.sendGeofenceRequest(properties: props, headers: [String: String](), timeoutInterval: profile.requestTimeoutInterval) { [lastKnownLatitude, lastKnownLongitude, geofenceHistory, now] (result, error) in

                if error != nil {
                    self.geofenceHistory.lastKnownLatitude = lastKnownLatitude ?? geofenceHistory.lastKnownLatitude
                    self.geofenceHistory.lastKnownLongitude = lastKnownLongitude ?? geofenceHistory.lastKnownLongitude
                    if self.geofenceHistory.errorHistory.count > VisilabsConstants.GEOFENCE_HISTORY_ERROR_MAX_COUNT {
                        let ascendingKeys = Array(self.geofenceHistory.errorHistory.keys).sorted(by: { $0 < $1 })
                        let keysToBeDeleted = ascendingKeys[0..<(ascendingKeys.count - VisilabsConstants.GEOFENCE_HISTORY_ERROR_MAX_COUNT)]
                        for key in keysToBeDeleted {
                            self.geofenceHistory.errorHistory[key] = nil
                        }
                    }
                    VisilabsPersistence.saveVisilabsGeofenceHistory(self.geofenceHistory)
                    return
                }
                (self.lastSuccessfulGeofenceFetchTime, self.geofenceHistory.lastFetchTime) = (now, now)
                var fetchedGeofences = [VisilabsGeofenceEntity]()
                if let res = result {
                    for targetingAction in res {
                        if let actionId = targetingAction["actid"] as? Int, let targetEvent = targetingAction["trgevt"] as? String, let durationInSeconds = targetingAction["dis"] as? Int, let geofences = targetingAction["geo"] as? [[String: Any]] {
                            for geofence in geofences {
                                if let geofenceId = geofence["id"] as? Int, let latitude = geofence["lat"] as? Double, let longitude = geofence["long"] as? Double, let radius = geofence["rds"] as? Double {
                                    var distanceFromCurrentLastKnownLocation: Double?
                                    if let lastLat = lastKnownLatitude, let lastLong = lastKnownLongitude {
                                        distanceFromCurrentLastKnownLocation = VisilabsHelper.distanceSquared(lat1: lastLat, lng1: lastLong, lat2: latitude, lng2: longitude)
                                    }
                                    fetchedGeofences.append(VisilabsGeofenceEntity(actId: actionId, geofenceId: geofenceId, latitude: latitude, longitude: longitude, radius: radius, durationInSeconds: durationInSeconds, targetEvent: targetEvent, distanceFromCurrentLastKnownLocation: distanceFromCurrentLastKnownLocation))
                                }
                            }
                        }
                    }
                }
                self.geofenceHistory.lastFetchTime = now
                self.geofenceHistory.lastKnownLatitude = lastKnownLatitude
                self.geofenceHistory.lastKnownLongitude = lastKnownLongitude
                self.geofenceHistory.fetchHistory[now] = fetchedGeofences
                if self.geofenceHistory.fetchHistory.count > VisilabsConstants.GEOFENCE_HISTORY_MAX_COUNT {
                    let ascendingKeys = Array(self.geofenceHistory.fetchHistory.keys).sorted(by: { $0 < $1 })
                    let keysToBeDeleted = ascendingKeys[0..<(ascendingKeys.count - VisilabsConstants.GEOFENCE_HISTORY_MAX_COUNT)]
                    for key in keysToBeDeleted {
                        self.geofenceHistory.fetchHistory[key] = nil
                    }
                }
                //self.geofenceHistory = geofenceHistory
                VisilabsPersistence.saveVisilabsGeofenceHistory(self.geofenceHistory)
                self.startMonitorGeofences(geofences: fetchedGeofences)
            }
        }
    }

    func sendPushNotification(actionId: String, geofenceId: String, isDwell: Bool, isEnter: Bool) {
        let user = VisilabsPersistence.unarchiveUser()
        var props = [String: String]()
        props[VisilabsConstants.ORGANIZATIONID_KEY] = profile.organizationId
        props[VisilabsConstants.PROFILEID_KEY] = profile.profileId
        props[VisilabsConstants.COOKIEID_KEY] = user.cookieId
        props[VisilabsConstants.EXVISITORID_KEY] = user.exVisitorId
        props[VisilabsConstants.ACT_KEY] = VisilabsConstants.PROCESSV2
        props[VisilabsConstants.ACT_ID_KEY] = actionId
        props[VisilabsConstants.TOKENID_KEY] = user.tokenId
        props[VisilabsConstants.APPID_KEY] = user.appId
        props[VisilabsConstants.GEO_ID_KEY] = geofenceId

        if isDwell {
            if isEnter {
                props[VisilabsConstants.TRIGGER_EVENT_KEY] = VisilabsConstants.ON_ENTER
            } else {
                props[VisilabsConstants.TRIGGER_EVENT_KEY] = VisilabsConstants.ON_EXIT
            }
        }

        for (key, value) in VisilabsPersistence.readTargetParameters() {
           if !key.isEmptyOrWhitespace && !value.isEmptyOrWhitespace && props[key] == nil {
               props[key] = value
           }
        }
        VisilabsLogger.error("Geofence Triggerred: actionId: \(actionId) geofenceid: \(geofenceId)")
        VisilabsRequest.sendGeofenceRequest(properties: props, headers: [String: String](), timeoutInterval: profile.requestTimeoutInterval) { (_, error) in
            if let error = error {
                VisilabsLogger.error("Geofence Push Send Error: \(error)")
            }
        }
    }

}

class VisilabsGeofence2: NSObject, CLLocationManagerDelegate {

    internal var lastLocationManagerCreated: Date?
    internal var maximumDesiredLocationAccuracy: CLLocationAccuracy = 30 // TODO: burada 30 yerine başka değer vermek doğru mu? önceden kCLLocationAccuracyHundredMeters kullanıyorduk.
    let organizationId: String
    let siteId: String

    lazy var locationManager: CLLocationManager = {
        lastLocationManagerCreated = Date()

        let manager = CLLocationManager()
        manager.distanceFilter = kCLDistanceFilterNone
        manager.desiredAccuracy = self.maximumDesiredLocationAccuracy
        manager.pausesLocationUpdatesAutomatically = false

        manager.delegate = self

        return manager
    }()

    init(organizationId: String, siteId: String) {
        self.organizationId = organizationId
        self.siteId = siteId
    }

    // MARK: - iOS bug workaround

    // to work around an iOS 13.3 bug that results in the location manager "dying", no longer receiving location updates
    public func recreateTheLocationManager() {

        // don't recreate location managers too often
        //if let last = lastLocationManagerCreated, last.age! < .oneMinute { return }

        if let llmc = lastLocationManagerCreated, llmc > Date().addingTimeInterval(-TimeInterval(60)) {
            return
        }

        lastLocationManagerCreated = Date()

        let freshManager = CLLocationManager()
        freshManager.distanceFilter = locationManager.distanceFilter
        freshManager.desiredAccuracy = locationManager.desiredAccuracy
        freshManager.pausesLocationUpdatesAutomatically = false
        freshManager.allowsBackgroundLocationUpdates = true
        freshManager.delegate = self

        // hand over to new manager
        freshManager.startUpdatingLocation()
        locationManager.stopUpdatingLocation()
        locationManager = freshManager

        VisilabsLogger.warn("Recreated the LocationManager")
    }

}
