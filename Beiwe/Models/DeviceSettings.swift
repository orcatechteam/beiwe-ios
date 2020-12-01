//
// Created by Jonathan Lee on 11/24/20.
// Copyright (c) 2020 ORCATECH. All rights reserved.
//

import Foundation
import ObjectMapper;

struct DeviceSettings : Mappable {

    var checkForNewSettingsFreqSeconds = 60; // 21600;

    var accelerometer  = false;
    var calls = false;
    var gps = false;
    var bluetooth = false;
    var powerState = false;
    var wifi = false;
    var proximity = false;
    var magnetometer = false;
    var gyro = false;
    var motion = false;
    var reachability = false;
    var texts = false;

    init?(map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
        accelerometer                   <- map["device_settings.accelerometer"];
        bluetooth                       <- map["device_settings.bluetooth"]
        calls                           <- map["device_settings.calls"]
        gps                             <- map["device_settings.gps"]
        powerState                      <- map["device_settings.power_state"]
        texts                           <- map["device_settings.texts"]
        wifi                            <- map["device_settings.wifi"]
        proximity                       <- map["device_settings.proximity"];
        magnetometer                    <- map["device_settings.magnetometer"];
        gyro                           <- map["device_settings.gyro"];
        motion                         <- map["device_settings.devicemotion"];
        reachability                   <- map["device_settings.reachability"];
    }

}
