//
//  RegisterViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/23/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import Eureka
import SwiftValidator
import PKHUD
import PromiseKit

class RegisterViewController: FormViewController {

    static let commErrDelay = 7.0
    static let commErr = "The server you are trying to register with is currently unavailable"
    let autoValidation = false;
    let db = Recline.shared;
    var dismiss: ((_ didRegister: Bool) -> Void)?;

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        let font = UIFont.systemFont(ofSize: 13.0);
        SVTextRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        SVPasswordRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        var section = Section("Register for Study")
        section = section <<< SVAccountRow("patientId") {
                $0.title = "User ID:"
                $0.placeholder = "User ID";
                $0.rules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("tempPassword") {
                $0.title = "Temporary Password:"
                $0.placeholder = "Temp Password";
                $0.rules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("password") {
                $0.title = "New Password:"
                $0.placeholder = "New password";
                $0.rules = [RequiredRule(), RegexRule(regex: Constants.passwordRequirementRegex, message: Constants.passwordRequirementDescription)]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("confirmPassword") {
                $0.title = "Confirm Password:"
                $0.placeholder = "Confirm Password";
                $0.rules = [RequiredRule(), MinLengthRule(length: 1)]
                $0.autoValidation = autoValidation
            }
            <<< ButtonRow() {
                $0.title = "Register"
                }
                .onCellSelection {
                    [unowned self] cell, row in
                    if (!self.form.validateAll()) {
                        print("Bad validation.");
                        return
                    }
                    
                    PKHUD.sharedHUD.dimsBackground = true;
                    PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;
                    HUD.show(.progress);
                    let formValues = self.form.values();
                    let patientId: String? = formValues["patientId"] as! String?;
                    //let phoneNumber: String? = formValues["phone"] as! String?;
                    let phoneNumber: String? = "NOT_SUPPLIED"
                    let newPassword: String? = formValues["password"] as! String?;
                    let tempPassword: String? = formValues["tempPassword"] as! String?;
                    if let patientId = patientId, let phoneNumber = phoneNumber, let newPassword = newPassword {
                        self._registerStudy(patientId: patientId, phoneNumber: phoneNumber, tempPassword: tempPassword, newPassword: newPassword)
                    }
                }
            <<< ButtonRow() {
                $0.title = "Cancel";
                }.onCellSelection { [unowned self] cell, row in
                    if let dismiss = self.dismiss {
                        dismiss(false);
                    } else {
                        self.presentingViewController?.dismiss(animated: true, completion: nil);
                    }
        }

        form +++ section

        let passwordRow: SVPasswordRow? = form.rowBy(tag: "password");
        let confirmRow: SVPasswordRow? = form.rowBy(tag: "confirmPassword");
        confirmRow!.rules = [ConfirmationRule(confirmField: passwordRow!.cell.textField)]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func _createStudy(phoneNumber: String, patientId: String, studySettings: StudySettings) -> Promise<Study>{
        let study = Study(patientPhone: phoneNumber, patientId: patientId, studySettings: studySettings, apiUrl: Constants.apiUrl);
        study.clinicianPhoneNumber = ""
        study.raPhoneNumber = ""
        if studySettings.fuzzGps {
            study.fuzzGpsLatitudeOffset = self._generateLatitudeOffset()
            study.fuzzGpsLongitudeOffset = self._generateLongitudeOffset()
        }
        return self.db.save(study)
    }
    
    func _registerStudy(patientId: String, phoneNumber: String, tempPassword: String?, newPassword: String ) -> Void {
        let newBase64Password = Crypto.sharedInstance.sha256Base64URL(newPassword);
        let registerStudyRequest = RegisterStudyRequest(patientId: patientId, phoneNumber: phoneNumber, newPassword: newBase64Password);
        ApiManager.sharedInstance.password = tempPassword ?? "";
        ApiManager.sharedInstance.patientId = patientId;
        ApiManager.sharedInstance.makePostRequest(registerStudyRequest).map { (studySettings, _) in
            PersistentPasswordManager.sharedInstance.storePassword(newPassword)
            return studySettings
        }.then { studySettings in
            StudyManager.sharedInstance.purgeStudies().then { _ in
                self._createStudy(phoneNumber: phoneNumber, patientId: patientId, studySettings: studySettings)
            }
        }.map { _ in
            HUD.flash(.success, delay: 1);
        }.then { _ -> Promise<Bool> in
            StudyManager.sharedInstance.loadDefaultStudy();
        }.done { _ in
            self._dismiss()
        }.catch { error -> Void in
            print("error received from register: \(error)");
            var delay = 2.0;
            var err: HUDContentType;
            switch error {
            case ApiErrors.failedStatus(let code):
                switch code {
                case 403, 401:
                    err = .labeledError(title: "Registration failed", subtitle: "Incorrect patient ID or Password");
                case 405:
                    err = .label("UserID already registered on another device.  Please contact your study administrator to unregister any previous devices that may have been used");
                    delay = 10.0;
                case 400:
                    err = .label("This device could not be registered under the provided patient ID.  Please contact your study administrator");
                    delay = 10.0;
                default:
                    err = .label(RegisterViewController.commErr);
                    delay = RegisterViewController.commErrDelay
                }
            default:
                err = .label(RegisterViewController.commErr);
                delay = RegisterViewController.commErrDelay
            }
            HUD.flash(err, delay: delay)
        }
    }
    
    func _dismiss() -> Void {
        AppDelegate.sharedInstance().isLoggedIn = true;
        if let dismiss = self.dismiss {
            dismiss(true);
        } else {
            self.presentingViewController?.dismiss(animated: true, completion: nil);
        }
    }
    
    /*
     Generates a random offset between -1 and 1 (thats not between -0.2 and 0.2)
    */
    func _generateLatitudeOffset() -> Double {
        var ran = Double.random(in: -1...1)
        while(ran <= 0.2 && ran >= -0.2) {
            ran = Double.random(in: -1...1)
        }
        return ran
    }
    
    /*
     Generates a random offset between -180 and 180 (thats not between -10 and 10)
    */
    func _generateLongitudeOffset() -> Double {
        var ran = Double.random(in: -180...180)
        while(ran <= 10 && ran >= -10) {
            ran = Double.random(in: -180...180)
        }
        return ran
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
