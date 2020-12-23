//
// Created by Jonathan Lee on 12/7/20.
// Copyright (c) 2020 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

struct UploadSettingsRequest: Mappable, ApiRequest {

    static let apiEndpoint = "/upload_settings/ios/"
    typealias ApiReturnType = BodyResponse

    var settings: String?

    init(settings: String) {
        self.settings = settings
    }

    init?(map: Map) {

    }

    // Mappable
    // swiftlint:disable operator_usage_whitespace
    mutating func mapping(map: Map) {
        settings           <- map["settings"]
    }
    // swiftlint:enable operator_usage_whitespace

}
