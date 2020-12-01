//
// Created by Jonathan Lee on 11/24/20.
// Copyright (c) 2020 ORCATECH. All rights reserved.
//

import Foundation
import ObjectMapper

struct GetSettingsRequest : Mappable, ApiRequest {

    static let apiEndpoint = "/download_settings/ios/"
    typealias ApiReturnType = DeviceSettings;


    init() {
    }

    init?(map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
    }

}
