//
//  Constants.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/23/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

struct Constants {
    static let passwordRequirementRegex = "^.{6,}$";
    static let passwordRequirementDescription = "Must be at least 6 characters";

    static let defaultStudyId = "default";
    static let apiUrl = "https://beiwe.internal.orcatech.org:8080"
    
    static let onboardingTitle = "Welcome";
    static let onboardingText = "Welcome to the ORCATECH Mobile Research Tool. Please have your user ID and password, which were given to you by your clinician, available as you begin the registration process. Have a nice day!";
}
