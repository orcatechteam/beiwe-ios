//
//  Nonce.swift
//  Beiwe
//
//  Created by Thomas Riley on 10/2/19.
//  Copyright © 2019 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper;

class Nonce : Mappable {

    var nonce: String?

    required init?(map: Map) {
    }

    func mapping(map: Map) {
      nonce   <- map["nonce"]
    }
}
