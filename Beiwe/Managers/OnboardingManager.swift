//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit

class OnboardingManager : NSObject, ORKTaskViewControllerDelegate {

    var retainSelf: AnyObject?;
    var onboardingViewController: ORKTaskViewController!;

    var WelcomeStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: "WelcomeStep")
        instructionStep.image = UIImage(named: "welcome-image")
        instructionStep.title = Constants.onboardingTitle;
        instructionStep.text = Constants.onboardingText;
        return instructionStep;
    }

    override init() {
        super.init();
        var steps = [ORKStep]();

        steps += [WelcomeStep];
        steps += [ORKWaitStep(identifier: "WaitForRegister")];

        let task = ORKOrderedTask(identifier: "OnboardingTask", steps: steps)
        onboardingViewController = ORKTaskViewController(task: task, taskRun: nil);
        onboardingViewController.showsProgressInNavigationBar = false;
        onboardingViewController.delegate = self;
        retainSelf = self;
    }

    func closeOnboarding() {
        AppDelegate.sharedInstance().transitionToCurrentAppState();
        retainSelf = nil;
    }

    /* ORK Delegates */
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
        closeOnboarding();
        log.info("Onboarding closed");
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, didChange result: ORKTaskResult) {
        return;
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, shouldPresent step: ORKStep) -> Bool {
        return true;
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, learnMoreForStep stepViewController: ORKStepViewController) {
        // Present modal...
        let refreshAlert = UIAlertController(title: "Learning more!", message: "You're smart now", preferredStyle: UIAlertController.Style.alert)
        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
        }))

        onboardingViewController.present(refreshAlert, animated: true, completion: nil)
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, hasLearnMoreFor step: ORKStep) -> Bool {
        switch(step.identifier) {
        case "SecondStep":
            return true;
        default:
            return false;
        }
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        if let identifier = stepViewController.step?.identifier {
            switch(identifier) {
                case "WelcomeStep":
                    stepViewController.cancelButtonItem = nil;
                    stepViewController.continueButtonTitle = "Register"
                case "WaitForRegister":
                    let registerViewController = RegisterViewController();
                    registerViewController.dismiss = { [unowned self] didRegister in
                        self.onboardingViewController.dismiss(animated: true, completion: nil);
                        if (!didRegister) {
                            self.onboardingViewController.goBackward();
                        } else {
                            // They did register, so if we close this onboarding, it should restart up
                            // with the consent form.
                            self.closeOnboarding();
                        }
                    }
                    onboardingViewController.present(registerViewController, animated: true, completion: nil)
            default: break
            }
        }
    }
}
