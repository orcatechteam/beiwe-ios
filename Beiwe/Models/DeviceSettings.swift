//
// Created by Jonathan Lee on 11/24/20.
// Copyright (c) 2020 ORCATECH. All rights reserved.
//

import Foundation
import ObjectMapper;

// Note that while it's related to PermissionStatus, it's not the same and it mainly deals with settings coming from the backend
enum DevicePermission: String {
    case requested = "requested" // initial state... also "undetermined" state
    case denied = "denied" // when a user explicitly denies
    case enabled = "enabled" // when a user grants the permission
    case disabled = "disabled" // when a data stream is unused OR no longer needed

    func isRequested() -> Bool { self == .requested }
    func isDenied() -> Bool { self == .denied }
    func isEnabled() -> Bool { self == .enabled }
    func isDisabled() -> Bool { self == .disabled }
}

struct DeviceSettings : Mappable {

    var checkForNewSettingsFreqSeconds = 60; // 21600;
    var accelerometer: DevicePermission = .requested
    var calls: DevicePermission = .requested
    var gps: DevicePermission = .requested
    var bluetooth: DevicePermission = .requested
    var powerState: DevicePermission = .requested
    var wifi: DevicePermission = .requested
    var proximity: DevicePermission = .requested
    var magnetometer: DevicePermission = .requested
    var gyro: DevicePermission = .requested
    var motion: DevicePermission = .requested
    var reachability: DevicePermission = .requested
    var texts: DevicePermission = .requested

    init?(map: Map) {
    }

    // Mappable
    mutating func mapping(map: Map) {
        accelerometer <- map["device_settings.accelerometer"]
        bluetooth     <- map["device_settings.bluetooth"]
        calls         <- map["device_settings.calls"]
        gps           <- map["device_settings.gps"]
        powerState    <- map["device_settings.power_state"]
        texts         <- map["device_settings.texts"]
        wifi          <- map["device_settings.wifi"]
        proximity     <- map["device_settings.proximity"]
        magnetometer  <- map["device_settings.magnetometer"]
        gyro          <- map["device_settings.gyro"]
        motion        <- map["device_settings.devicemotion"]
        reachability  <- map["device_settings.reachability"]
    }

}
