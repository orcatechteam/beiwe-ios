//
//  LoginViewV2Controller.swift
//  Beiwe
//
//  Created by Jonathan Lee on 6/10/21.
//  Copyright © 2021 ORCATECH. All rights reserved.
//

import UIKit
import ResearchKit

enum StepIdentifier: String {
    case Login
    case LoggingIn
}

// This is a rebooted version of the login view controller that uses researchkit tasks
class LoginViewV2Controller: UIViewController, ORKTaskViewControllerDelegate {
    var taskViewController: ORKTaskViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        let lbl = UILabel()
        lbl.text = ""
        lbl.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        lbl.backgroundColor = .yellow
        self.view.addSubview(lbl)

        let loginStepTitle = "Login"
        let loginStepText = "Enter your password to continue"

        class LoginController: ORKLoginStepViewController {
            override func forgotPasswordButtonTapped() {
                let vc = ChangePasswordViewController()
                vc.isForgotPassword = true
                vc.finished = { _ in
                    self.dismiss(animated: true, completion: nil)
                }
                self.present(vc, animated: true, completion: nil)
            }
        }
        let loginStep = ORKLoginStep(identifier: StepIdentifier.Login.rawValue, title: loginStepTitle, text: "", loginViewControllerClass: LoginController.self)
        let passwordField = loginStep.formItems![1]
        passwordField.detailText = loginStepText
        loginStep.formItems = [passwordField]
        loginStep.iconImage = UIImage(named: "orcatech-temp")

        let waitStep = ORKWaitStep(identifier: StepIdentifier.LoggingIn.rawValue)
        waitStep.title = "Logging in"
        waitStep.text = "Please wait while we check your credentials"

        let loginTask = ORKOrderedTask(identifier: "task", steps: [loginStep, waitStep])

        let taskViewControllerr = ORKTaskViewController(task: loginTask, taskRun: nil)
        taskViewControllerr.delegate = self
        taskViewControllerr.modalPresentationStyle = .fullScreen
        taskViewControllerr.setNavigationBarHidden(true, animated: false)
        present(taskViewControllerr, animated: false, completion: nil)

        taskViewController = taskViewControllerr
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        log.info("task finished")
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        if let identifier = stepViewController.step?.identifier {
            switch(identifier) {
            case StepIdentifier.Login.rawValue:
                stepViewController.cancelButtonItem = nil
            case StepIdentifier.LoggingIn.rawValue:
                log.info(StepIdentifier.LoggingIn)
                let loginStepResult = taskViewController.result.result(forIdentifier: "Login") as? ORKStepResult
                let passwordResult = loginStepResult?.results![0] as? ORKTextQuestionResult
                let passwordText = passwordResult?.textAnswer ?? ""
                let validPass = AppDelegate.sharedInstance().checkPasswordAndLogin(passwordText)
                if passwordText.count > 0 && validPass {
                    AppDelegate.sharedInstance().transitionToCurrentAppState();
                } else {
                    let wrongPassAlert = UIAlertController(title: "Incorrect password", message: "The password provided was incorrect", preferredStyle: UIAlertController.Style.alert)
                    wrongPassAlert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { (action: UIAlertAction!) in
                        self.taskViewController.goBackward()
                    }))
                    self.taskViewController.present(wrongPassAlert, animated: true, completion: nil)
                }
            default: break
            }
        }
    }
}
