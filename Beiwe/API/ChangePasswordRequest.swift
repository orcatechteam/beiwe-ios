//
//  ChangePasswordRequest.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/19/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

struct ChangePasswordRequest : Mappable, ApiRequest {

    static let apiEndpoint = "/set_password/ios/"
    typealias ApiReturnType = BodyResponse;

    var newPassword: String?;
    var pwMode: String?;
    


    init(newPassword: String, pwMode: String) {
        self.newPassword = newPassword;
        self.pwMode = pwMode;
    }

    init?(map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
        newPassword <- map["new_password"];
        pwMode <- map["pw_mode"];
    }
    
}
