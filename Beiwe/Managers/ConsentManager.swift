//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit
import Permission

enum StepIds: String {
    case Permission = "PermissionsStep"
    case WaitForPermissions = "WaitForPermissions"
    case WarningStep = "WarningStep"
    case VisualConsent = "VisualConsentStep"
    case ConsentReview = "ConsentReviewStep"
}

class WaitForPermissionsRule: ORKStepNavigationRule {
    let nextTask: (ORKTaskResult) -> String
    init(nextTask: @escaping (_ taskResult: ORKTaskResult) -> String) {
        self.nextTask = nextTask

        super.init(coder: NSCoder())
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func identifierForDestinationStep(with taskResult: ORKTaskResult) -> String {
        return self.nextTask(taskResult)
    }
}

@objc class ConsentManager: NSObject, ORKTaskViewControllerDelegate {
    var retainSelf: AnyObject?
    var consentViewController: ORKTaskViewController!
    var consentDocument: ORKConsentDocument!

    var PermissionsStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: StepIds.Permission.rawValue)
        instructionStep.title = "Permissions"
        let gpsNeeded = StudyManager.sharedInstance.currentStudy?.studySettings?.gps.isRequested() ?? false
        if gpsNeeded {
            instructionStep.text = """
                Beiwe needs access to your location for the passive data gathering capabilities of this app. 
                Beiwe will also send you notifications to notify you of new surveys.
                """
        } else {
            instructionStep.text = "Beiwe needs permission to send you notifications to notify you of new surveys or updates."
        }
        return instructionStep
    }

    var WarningStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: StepIds.WarningStep.rawValue)
        instructionStep.title = "Warning"
        instructionStep.text = """
            Permission to access your location is required to correctly gather the data required for this study.  
            To participate in this study we highly recommend you go back and allow this application to access your location.
            """
        return instructionStep
    }

    var permissionStatus: [PermissionStatus] = []
    var expectedPermissionCount: Int = 0

    override init() {
        log.info("# # >> ConsentMgr.init << # #")
        super.init()

        // Set up permissions

        var steps = [ORKStep]()
        if !hasRequiredPermissions() {
            steps += [PermissionsStep]
            steps += [ORKWaitStep(identifier: StepIds.WaitForPermissions.rawValue)]
            let gpsNeeded = StudyManager.sharedInstance.currentStudy?.studySettings?.gps.isRequested() ?? false
            if gpsNeeded {
                steps += [WarningStep]
            }
        }

        consentDocument = ORKConsentDocument()
        consentDocument.title = "Beiwe Consent"

        let studyConsentSections = StudyManager.sharedInstance.currentStudy?.studySettings?.consentSections ?? [:]

        let overviewSection = ORKConsentSection(type: .overview)
        if let welcomeStudySection = studyConsentSections["welcome"], !welcomeStudySection.text.isEmpty {
            overviewSection.summary = welcomeStudySection.text
            if !welcomeStudySection.more.isEmpty {
                overviewSection.content = welcomeStudySection.more
            }
        } else {
            overviewSection.summary = "Welcome to the study"
        }

        let consentSectionTypes: [(ORKConsentSectionType, String)] = [
            (.dataGathering, "data_gathering"),
            (.privacy, "privacy"),
            (.dataUse, "data_use"),
            (.timeCommitment, "time_commitment"),
            (.studySurvey, "study_survey"),
            (.studyTasks, "study_tasks"),
            (.withdrawing, "withdrawing")
        ]

        var hasAdditionalConsent = false
        var consentSections: [ORKConsentSection] = [overviewSection]
        for (contentSectionType, bwType) in consentSectionTypes {
            if let bwSection = studyConsentSections[bwType], !bwSection.text.isEmpty {
                hasAdditionalConsent = true
                let consentSection = ORKConsentSection(type: contentSectionType)
                consentSection.summary = bwSection.text
                if !bwSection.more.isEmpty {
                    consentSection.content = bwSection.more
                }
                consentSections.append(consentSection)
            }
        }

        consentDocument.addSignature(ORKConsentSignature(forPersonWithTitle: nil, dateFormatString: nil, identifier: "ConsentDocumentParticipantSignature"))

        consentDocument.sections = consentSections // TODO: signature

        let visualConsentStep = ORKVisualConsentStep(identifier: StepIds.VisualConsent.rawValue, document: consentDocument)
        steps += [visualConsentStep]

        if hasAdditionalConsent {
            let reviewConsentStep = ORKConsentReviewStep(identifier: StepIds.ConsentReview.rawValue, signature: nil, in: consentDocument)

            reviewConsentStep.text = "Review Consent"
            reviewConsentStep.reasonForConsent = "Consent to join study"

            steps += [reviewConsentStep]
        }

        log.info("ConsentMgr.init()//consentSections: `\(consentSections.count)`")
        log.info("ConsentMgr.init()//steps: `\(steps.count)`")
        let task = ORKNavigableOrderedTask(identifier: "ConsentTask", steps: steps)
        task.setNavigationRule(WaitForPermissionsRule { _ -> String in
            if Permission.locationAlways.status == .authorized {
                return StepIds.VisualConsent.rawValue
            } else {
                return StepIds.WarningStep.rawValue
            }

            }, forTriggerStepIdentifier: StepIds.WaitForPermissions.rawValue)
        consentViewController = ORKTaskViewController(task: task, taskRun: nil)
        consentViewController.showsProgressInNavigationBar = false
        consentViewController.delegate = self
        retainSelf = self
    }

    func closeOnboarding() {
        AppDelegate.sharedInstance().transitionToCurrentAppState()
        retainSelf = nil
    }

    func hasRequiredPermissions() -> Bool {
        (Permission.notifications.status == .authorized && Permission.locationAlways.status == .authorized)
    }

    /* ORK Delegates */

    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        if reason == ORKTaskViewControllerFinishReason.discarded {
            _ = StudyManager.sharedInstance.leaveStudy().done { _ in
                self.closeOnboarding()
            }
        } else {
            _ = StudyManager.sharedInstance.setConsented().done { _ in
                self.closeOnboarding()
            }
        }
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, didChange result: ORKTaskResult) {
        return
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, shouldPresent step: ORKStep) -> Bool {
        return true
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, learnMoreForStep stepViewController: ORKStepViewController) {
        // Present modal...
        let refreshAlert = UIAlertController(title: "Learning more!", message: "You're smart now", preferredStyle: UIAlertController.Style.alert)

        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in }))

        consentViewController.present(refreshAlert, animated: true, completion: nil)
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, hasLearnMoreFor step: ORKStep) -> Bool {
        return false
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        return nil
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        log.info("ConsentMgr.taskViewController")
        stepViewController.cancelButtonItem!.title = "Leave Study"

        if let identifier = StepIds(rawValue: stepViewController.step?.identifier ?? "") {
            switch identifier {
            case .WaitForPermissions:
                self.expectedPermissionCount = 1
                Permission.notifications.request({ status in
                    // Note: this permission is device specific and does not flow to the backend
                    self.permissionStatus.append(status)
                    self.handlePermissionSet(stepViewController: stepViewController)
                })
                let gpsNeeded = StudyManager.sharedInstance.currentStudy?.studySettings?.gps.isRequested() ?? false
                if gpsNeeded {
                    Permission.locationAlways.request({ status in
                        self.permissionStatus.append(status)
                        self.handlePermissionSet(stepViewController: stepViewController)
                    })
                    self.expectedPermissionCount = 2
                }
            case .Permission:
                stepViewController.continueButtonTitle = "Continue"
            case .WarningStep:
                let gpsNeeded = StudyManager.sharedInstance.currentStudy?.studySettings?.gps.isRequested() ?? false
                if !gpsNeeded {
                    stepViewController.goForward()
                    StudyManager.sharedInstance.handleLocationPermissionStatus(.denied)
                } else {
                    if Permission.locationAlways.status == .authorized {
                        stepViewController.goForward()
                    } else {
                        stepViewController.continueButtonTitle = "Continue"
                    }
                }
            case .VisualConsent:
                if hasRequiredPermissions() {
                    stepViewController.backButtonItem = nil
                }
            default:
                break
            }
        }
    }

    func handlePermissionSet(stepViewController: ORKStepViewController) {
        // @TODO:FEATURE Update to handle when permissions were denied
        if permissionStatus.count >= expectedPermissionCount {
            stepViewController.goForward()
        }
    }
}
