//
//  StudyManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit
import ReachabilitySwift
import EmitterKit
import Crashlytics

class StudyManager {
    static let sharedInstance = StudyManager();

    let MAX_UPLOAD_DATA: Int64 = 250 * (1024 * 1024)
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let calendar = Calendar.current;
    var keyRef: SecKey?;

    var currentStudy: Study?;
    var gpsManager: GPSManager?;
    var isUploading = false;
    let surveysUpdatedEvent: Event<Int> = Event<Int>();
    var isStudyLoaded: Bool {
        return currentStudy != nil;
    }

    func loadDefaultStudy() -> Promise<Bool> {
        currentStudy = nil;
        gpsManager = nil;
        return Recline.shared.queryAll().then { (studies: [Study]) -> Promise<Bool> in
            if (studies.count > 1) {
                log.error("Multiple Studies: \(studies)")
                Crashlytics.sharedInstance().recordError(NSError(domain: "com.rf.beiwe.studies", code: 1, userInfo: nil))
            }
            if (studies.count > 0) {
                self.currentStudy = studies[0];
                AppDelegate.sharedInstance().setDebuggingUser(self.currentStudy?.patientId ?? "unknown")
            }
            return Promise.value(true);
        }

    }

    func setApiCredentials() {
        guard let currentStudy = currentStudy, gpsManager == nil else {
            return;
        }

        /* Setup APIManager's security */
        ApiManager.sharedInstance.password = PersistentPasswordManager.sharedInstance.passwordForStudy() ?? "";
        if let patientId = currentStudy.patientId {
            ApiManager.sharedInstance.patientId = patientId;
            if let clientPublicKey = currentStudy.studySettings?.clientPublicKey {
                do {
                    let pkey = try PersistentPasswordManager.sharedInstance.storePublicKeyForStudy(clientPublicKey, patientId: patientId);
                    keyRef = pkey
                } catch {
                    log.error("Failed to store RSA key in keychain.");
                }
            } else {
                log.error("No public key found.  Can't store");
            }
        }
    }
    
    func startStudyDataServices() {
        if gpsManager != nil {
            return;
        }
        setApiCredentials()
        DataStorageManager.sharedInstance.setCurrentStudy(self.currentStudy!, secKeyRef: keyRef);
        self.prepareDataServices();
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: ReachabilityChangedNotification, object: nil)

    }

    func prepareDataServices() {
        guard let studySettings = currentStudy?.studySettings else {
            return;
        }

        log.info("prepareDataServices")

        DataStorageManager.sharedInstance.createDirectories();
        /* Move non current files out.  Probably not necessary, would happen later anyway */
        _ = DataStorageManager.sharedInstance.prepareForUpload();
        gpsManager = GPSManager();
        
        // Check if gps fuzzing is enabled for currentStudy
        gpsManager?.enableGpsFuzzing = studySettings.fuzzGps ? true : false
        gpsManager?.fuzzGpsLatitudeOffset = (currentStudy?.fuzzGpsLatitudeOffset)!
        gpsManager?.fuzzGpsLongitudeOffset = (currentStudy?.fuzzGpsLongitudeOffset)!
        
        gpsManager!.addDataService(AppEventManager.sharedInstance)
        if (studySettings.gps && studySettings.gpsOnDurationSeconds > 0) {
            log.info("preparing gps for data svc...")
            gpsManager!.addDataService(studySettings.gpsOnDurationSeconds, off: studySettings.gpsOffDurationSeconds, handler: gpsManager!)
        }
        if (studySettings.accelerometer && studySettings.gpsOnDurationSeconds > 0) {
            log.info("preparing accel for data svc...")
            gpsManager!.addDataService(studySettings.accelerometerOnDurationSeconds, off: studySettings.accelerometerOffDurationSeconds, handler: AccelerometerManager());
        }
        if (studySettings.powerState) {
            log.info("preparing power state for data svc...")
            gpsManager!.addDataService(PowerStateManager());
        }

        if (studySettings.proximity) {
            log.info("preparing proximity for data svc...")
            gpsManager!.addDataService(ProximityManager());
        }

        if (studySettings.reachability) {
            log.info("preparing reachability for data svc...")
            gpsManager!.addDataService(ReachabilityManager());
        }

        if (studySettings.gyro) {
            log.info("preparing gyro for data svc...")
            gpsManager!.addDataService(studySettings.gyroOnDurationSeconds, off: studySettings.gyroOffDurationSeconds, handler: GyroManager());
        }

        if (studySettings.magnetometer && studySettings.magnetometerOnDurationSeconds > 0) {
            log.info("preparing magnetometer for data svc...")
            gpsManager!.addDataService(studySettings.magnetometerOnDurationSeconds, off: studySettings.magnetometerOffDurationSeconds, handler: MagnetometerManager());
        }

        if (studySettings.motion && studySettings.motionOnDurationSeconds > 0) {
            log.info("preparing motion for data svc...")
            gpsManager!.addDataService(studySettings.motionOnDurationSeconds, off: studySettings.motionOffDurationSeconds, handler: DeviceMotionManager());
        }

        if studySettings.gps {
            _ = gpsManager!.startGpsAndTimer();
        } else {
            _ = gpsManager!.startTimer();
        }
    }

    func setConsented() -> Promise<Bool> {
        guard let study = currentStudy, let studySettings = study.studySettings else {
            return Promise.value(false);
        }
        setApiCredentials()
        let currentTime: Int64 = Int64(Date().timeIntervalSince1970);
        study.nextUploadCheck = currentTime + Int64(studySettings.uploadDataFileFrequencySeconds);
        study.nextSurveyCheck = currentTime + Int64(studySettings.checkForNewSurveysFreqSeconds);
        study.nextSettingsCheck = currentTime + Int64(study.settingsCheckFrequency);

        study.participantConsented = true;
        DataStorageManager.sharedInstance.setCurrentStudy(study, secKeyRef: keyRef)
        DataStorageManager.sharedInstance.createDirectories();
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return self.checkSurveys();
        }
    }

    func purgeStudies() -> Promise<Bool> {
        return Recline.shared.queryAll().then { (studies: [Study]) -> Promise<Bool> in
            var promise = Promise.value(true)
            for study in studies {
                promise = promise.then { _ in
                    return Recline.shared.purge(study)
                }
            }
            return promise
        }
    }

    func stop() -> Promise<Bool> {
        let queue = DispatchQueue.global(qos: .default)
        
        var promise: Promise<Void>
        if (gpsManager != nil) {
            promise = gpsManager!.stopAndClear()
        } else {
            promise = Promise();
        }
    
        return promise.then(on: queue) { _ -> Promise<Bool> in
            //self.gpsManager = nil;
            self.currentStudy = nil;
            return Promise.value(true)
        }
    }

    func leaveStudy() -> Promise<Bool> {

        /*
        guard let study = currentStudy else {
            return Promise(true);
        }
        */

        NotificationCenter.default.removeObserver(self, name: ReachabilityChangedNotification, object:nil);

        var promise: Promise<Void>
        if (gpsManager != nil) {
            promise = gpsManager!.stopAndClear().map{ _ in self.gpsManager = nil }
        } else {
            promise = Promise();
        }


        UIApplication.shared.cancelAllLocalNotifications()
        return promise.then { _ -> Promise<Bool> in
            self.purgeStudies()
        }.then { _ in
            self._removeStudyFiles()
        }
    }

    func _removeStudyFiles() -> Promise<Bool> {
        return Promise { seal in
            let fileManager = FileManager.default
            var enumerator = fileManager.enumerator(atPath: DataStorageManager.uploadDataDirectory().path);

            if let enumerator = enumerator {
                while let filename = enumerator.nextObject() as? String {
                    if (true /*filename.hasSuffix(DataStorageManager.dataFileSuffix)*/) {
                        let filePath = DataStorageManager.uploadDataDirectory().appendingPathComponent(filename);
                        try fileManager.removeItem(at: filePath);
                    }
                }
            }

            enumerator = fileManager.enumerator(atPath: DataStorageManager.currentDataDirectory().path);

            if let enumerator = enumerator {
                while let filename = enumerator.nextObject() as? String {
                    if (true /* filename.hasSuffix(DataStorageManager.dataFileSuffix) */) {
                        let filePath = DataStorageManager.currentDataDirectory().appendingPathComponent(filename);
                        try fileManager.removeItem(at: filePath);
                    }
                }
            }
            
            self.currentStudy = nil;
            seal.fulfill(true)
        }
    }
    
    @objc func reachabilityChanged(_ notification: Notification){
        _ = Promise().done {
            log.info("Reachability changed, running periodic.");
            self.periodicNetworkTransfers();
        }
    }

    func periodicNetworkTransfers() {
        guard let currentStudy = currentStudy, let studySettings = currentStudy.studySettings else {
            return;
        }

        var reachable = false
        if self.appDelegate.reachability != nil {
            reachable = studySettings.uploadOverCellular ? self.appDelegate.reachability!.isReachable : self.appDelegate.reachability!.isReachableViaWiFi
        }
        
        // Good time to compact the database
        let currentTime: Int64 = Int64(Date().timeIntervalSince1970);
        let nextSurvey = currentStudy.nextSurveyCheck ?? 0;
        let nextUpload = currentStudy.nextUploadCheck ?? 0;
        let nextSettings = currentStudy.nextSettingsCheck ?? 0;
        
        log.info("CurrentTime " + currentTime.description + ", NextUpload: " + nextUpload.description)

        if (currentTime > nextSettings) {
            self.setNextSettingsTime().done { _ in
                if (reachable) {
                    _ = self.checkSettings();
                }
            }.catch { _ in
                log.error("Error checking for surveys");
            }
        }

        if (currentTime > nextSurvey || (reachable && currentStudy.missedSurveyCheck)) {
            /* This will be saved because setNextUpload saves the study */
            currentStudy.missedSurveyCheck = !reachable
            self.setNextSurveyTime().done { _ in
                if (reachable) {
                    _ = self.checkSurveys();
                }
            }.catch { _ in
                log.error("Error checking for surveys");
            }
        }
        else if (currentTime > nextUpload || (reachable && currentStudy.missedUploadCheck)) {
            log.info("Will upload at next upload time")
            /* This will be saved because setNextUpload saves the study */
            currentStudy.missedUploadCheck = !reachable
            self.setNextUploadTime().done { _ in
                _ = self.upload(!reachable);
            }.catch { _ in
                log.error("Error checking for uploads")
            }
        }


    }

    func cleanupSurvey(_ activeSurvey: ActiveSurvey) {
        removeNotificationForSurvey(activeSurvey);
        if let surveyId = activeSurvey.survey?.surveyId {
            let timingsName = TrackingSurveyPresenter.timingDataType + "_" + surveyId;
            _ = DataStorageManager.sharedInstance.closeStore(timingsName);
        }
    }

    func submitSurvey(_ activeSurvey: ActiveSurvey, surveyPresenter: TrackingSurveyPresenter? = nil) {
        if let survey = activeSurvey.survey, let surveyId = survey.surveyId, let surveyType = survey.surveyType, surveyType == .TrackingSurvey {
            var trackingSurvey: TrackingSurveyPresenter;
            if (surveyPresenter == nil) {
                trackingSurvey = TrackingSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey)
                trackingSurvey.addTimingsEvent("expired", question: nil)
            } else {
                trackingSurvey = surveyPresenter!;
            }
            _ = trackingSurvey.finalizeSurveyAnswers();
            if (activeSurvey.bwAnswers.count > 0) {
                if let surveyType = survey.surveyType {
                    switch (surveyType) {
                    case .AudioSurvey:
                        currentStudy?.submittedAudioSurveys = (currentStudy?.submittedAudioSurveys ?? 0) + 1;
                    case .TrackingSurvey:
                        currentStudy?.submittedTrackingSurveys = (currentStudy?.submittedTrackingSurveys ?? 0) + 1;

                    }
                }
            }
        }

        cleanupSurvey(activeSurvey);
    }

    func removeNotificationForSurvey(_ survey: ActiveSurvey) {
        guard let notification = survey.notification else {
            return;
        }
        let alertBody = notification.alertBody ?? ""
        log.info("Cancelling notification: \(alertBody), \(String(describing: notification.userInfo))")

        UIApplication.shared.cancelLocalNotification(notification);
        survey.notification = nil;
    }

    func updateActiveSurveys(_ forceSave: Bool = false) -> TimeInterval {
        log.info("Updating active surveys...")
        let currentDate = Date();
        let currentTime = currentDate.timeIntervalSince1970;
        let currentDay = (calendar as NSCalendar).component(.weekday, from: currentDate) - 1;
        var nowDateComponents = (calendar as NSCalendar).components([NSCalendar.Unit.day, NSCalendar.Unit.year, NSCalendar.Unit.month, NSCalendar.Unit.timeZone], from: currentDate);
        nowDateComponents.hour = 0;
        nowDateComponents.minute = 0;
        nowDateComponents.second = 0;

        var closestNextSurveyTime: TimeInterval = currentTime + (60.0*60.0*24.0*7);

        guard let study = currentStudy, let dayBegin = calendar.date(from: nowDateComponents)  else {
            return Date().addingTimeInterval((15.0*60.0)).timeIntervalSince1970;
        }


        var surveyDataModified = false;

        /* For all active surveys that aren't complete, but have expired, submit them */
        for (id, activeSurvey) in study.activeSurveys {
            // THIS is basically the same thing as the else if statement below, EXCEPT we are resetting the survey.
            // this is so that we reset the state for a permananent survey. If we do not have this,
            // the survey stays at the "done" stage after you have completed the survey and does not allow
            // you to go back and retake a survey.  also, every time you load the survey to the done page,
            // it resaves a new version of the data in a file.
            if(activeSurvey.survey?.alwaysAvailable ?? false && activeSurvey.isComplete){
//                print("submitted 1")
                log.info("ActiveSurvey \(id) expired.");
                activeSurvey.isComplete = true;
                surveyDataModified = true;
                //  adding submitSurvey creates a new file; therefore we get 2 files of data- one when you
                //  hit the confirm button and one when this code executes. we DO NOT KNOW why this is in the else if statement
                //  below - however we are not keeping it in this if statement for the aforementioned problem.
                // submitSurvey(activeSurvey)
                activeSurvey.reset(activeSurvey.survey)
            }
            //TODO: we need to determine the correct exclusion logic, currently this submits ALL permanent surveys when ANY permanent survey loads.
            // This function gets called whenever you try to display the home page, thus it happens at a very odd time.
            else if (!activeSurvey.isComplete && activeSurvey.expires > 0 && activeSurvey.expires <= currentTime) {
//                print("submitted 2")
                log.info("ActiveSurvey \(id) expired.");
                activeSurvey.isComplete = true;
                surveyDataModified = true;
                submitSurvey(activeSurvey);
            }
        }

        var allSurveyIds: [String] = [ ];
        /* Now for each survey from the server, check on the scheduling */
        for survey in study.surveys {
            var next: Double = 0;
            /* Find the next scheduled date that is >= now */
            outer: for day in 0..<7 {
                let dayIdx = (day + currentDay) % 7;
                let timings = survey.timings[dayIdx].sorted()

                for dayTime in timings {
                    let possibleNxt = dayBegin.addingTimeInterval((Double(day) * 24.0 * 60.0 * 60.0) + Double(dayTime)).timeIntervalSince1970;
                    if (possibleNxt > currentTime ) {
                        next = possibleNxt;
                        break outer
                    }
                }
            }
            if let id = survey.surveyId  {
                if (next > 0) {
                    closestNextSurveyTime = min(closestNextSurveyTime, next);
                }
                allSurveyIds.append(id);
                /* If we don't know about this survey already, add it in there for TRIGGERONFIRSTDOWNLOAD surverys*/
                if study.activeSurveys[id] == nil && (survey.triggerOnFirstDownload || next > 0) {
                    log.info("Adding survey  \(id) to active surveys");
                    study.activeSurveys[id] = ActiveSurvey(survey: survey);
                    /* Schedule it for the next upcoming time, or immediately if triggerOnFirstDownload is true */
                    study.activeSurveys[id]?.expires = survey.triggerOnFirstDownload ? currentTime : next;
                    study.activeSurveys[id]?.isComplete = true;
                    log.info("Added survey \(id), expires: \(Date(timeIntervalSince1970: study.activeSurveys[id]!.expires))");
                    surveyDataModified = true;
                }
                /* We want to display permanent surveys as active, and expect to change some details below (currently identical to the actions we take on a regular active survey) */
                else if study.activeSurveys[id] == nil && (survey.alwaysAvailable) {
                    log.info("Adding survey  \(id) to active surveys");
                    study.activeSurveys[id] = ActiveSurvey(survey: survey);
                    /* Schedule it for the next upcoming time, or immediately if alwaysAvailable is true */
                    study.activeSurveys[id]?.expires = survey.alwaysAvailable ? currentTime : next;
                    study.activeSurveys[id]?.isComplete = true;
                    log.info("Added survey \(id), expires: \(Date(timeIntervalSince1970: study.activeSurveys[id]!.expires))");
                    surveyDataModified = true;
                }
                if let activeSurvey = study.activeSurveys[id] {
                    /* If it's complete (including surveys we force-completed above) and it's expired, it's time for the next one */
                    if (activeSurvey.isComplete && activeSurvey.expires <= currentTime && activeSurvey.expires > 0) {
                        activeSurvey.reset(survey);
                        activeSurvey.received = activeSurvey.expires;
                        /*
                        let trackingSurvey: TrackingSurveyPresenter = TrackingSurveyPresenter(surveyId: id, activeSurvey: activeSurvey, survey: survey)
                        trackingSurvey.addTimingsEvent("notified", question: nil)
                        */
                        TrackingSurveyPresenter.addTimingsEvent(id, event: "notified");

                        surveyDataModified = true;

                        /* Local notification goes here */

                        if let surveyType = survey.surveyType {
                            switch (surveyType) {
                            case .AudioSurvey:
                                currentStudy?.receivedAudioSurveys = (currentStudy?.receivedAudioSurveys ?? 0) + 1;
                            case .TrackingSurvey:
                                currentStudy?.receivedTrackingSurveys = (currentStudy?.receivedTrackingSurveys ?? 0) + 1;
                                
                            }

                            let localNotif = UILocalNotification();
                            localNotif.fireDate = currentDate;

                            var body: String;
                            switch(surveyType) {
                            case .TrackingSurvey:
                                body = "A new survey has arrived and is awaiting completion."
                            case .AudioSurvey:
                                body = "A new audio question has arrived and is awaiting completion."
                            }

                            localNotif.alertBody = body;
                            localNotif.soundName = UILocalNotificationDefaultSoundName;
                            localNotif.userInfo = [
                                "type": "survey",
                                "survey_type": surveyType.rawValue,
                                "survey_id": id
                            ];
                            log.info("Sending Survey notif: \(body), \(String(describing: localNotif.userInfo))")
                            UIApplication.shared.scheduleLocalNotification(localNotif);
                            activeSurvey.notification = localNotif;

                        }

                    }
                    if (activeSurvey.expires != next) {
                        activeSurvey.expires = next;
                        surveyDataModified = true;
                    }
                }
            }
        }


        /* Set the badge, and remove surveys no longer on server from our active surveys list */
        var badgeCnt = 0;
        for (id, activeSurvey) in study.activeSurveys {
            if (activeSurvey.isComplete && !allSurveyIds.contains(id)) {
                cleanupSurvey(activeSurvey);
                study.activeSurveys.removeValue(forKey: id);
                surveyDataModified = true;
            } else if (!activeSurvey.isComplete) {
                if (activeSurvey.expires > 0) {
                    closestNextSurveyTime = min(closestNextSurveyTime, activeSurvey.expires);
                }
                badgeCnt += 1;
            }
        }
        log.info("Badge Cnt: \(badgeCnt)");
        /*
        if (badgeCnt != study.lastBadgeCnt) {
            study.lastBadgeCnt = badgeCnt;
            surveyDataModified = true;
            let localNotif = UILocalNotification();
            localNotif.applicationIconBadgeNumber = badgeCnt;
            localNotif.fireDate = currentDate;
            UIApplication.sharedApplication().scheduleLocalNotification(localNotif);
        }
        */
        UIApplication.shared.applicationIconBadgeNumber = badgeCnt

        if (surveyDataModified || forceSave ) {
            surveysUpdatedEvent.emit(0)
            Recline.shared.save(study).catch { _ in
                log.error("Failed to save study after processing surveys");
            }
        }

        if let gpsManager = gpsManager  {
            gpsManager.resetNextSurveyUpdate(closestNextSurveyTime);
        }
        return closestNextSurveyTime;
    }

    func checkSurveys() -> Promise<Bool> {
        guard let study = currentStudy, let _ = study.studySettings else {
            return Promise.value(false);
        }
        log.info("Checking for surveys...");
        return Recline.shared.save(study).then { _ -> Promise<([Survey], Int)> in
                let surveyRequest = GetSurveysRequest();
                return ApiManager.sharedInstance.arrayPostRequest(surveyRequest);
            }.then { (surveys, _) -> Promise<Void> in
                log.info("Surveys: \(surveys)");
                study.surveys = surveys;
                return Recline.shared.save(study).asVoid();
            }.then { _ -> Promise<Bool> in
                _ = self.updateActiveSurveys();
                return Promise.value(true);
            }.recover { _ -> Promise<Bool> in
                return Promise.value(false);
        }

    }

    func checkSettings() -> Promise<Bool> {
        guard let study = currentStudy, let _ = study.studySettings else {
            return Promise.value(false);
        }
        log.info("Checking settings...");
        return Recline.shared.save(study).then { _ -> Promise<(DeviceSettings, Int)> in
            let settingsRequest = GetSettingsRequest();
            return ApiManager.sharedInstance.makePostRequest(settingsRequest);
        }.then { (deviceSettings, _) -> Promise<Void> in
            log.info("deviceSettings: \(deviceSettings)");
            study.deviceSettings = deviceSettings;
            if (deviceSettings.accelerometer != study.studySettings?.accelerometer) {
                log.info("StudyMgr.checkSettings//accelerometer changed from `\(study.studySettings?.accelerometer)` to `\(deviceSettings.accelerometer)`")
                study.studySettings?.accelerometer = deviceSettings.accelerometer;
            }
            if (deviceSettings.motion != study.studySettings?.motion) {
                log.info("StudyMgr.checkSettings//motion changed from `\(study.studySettings?.motion)` to `\(deviceSettings.motion)`")
                study.studySettings?.motion = deviceSettings.motion
            }
            if (deviceSettings.gps != study.studySettings?.gps) {
                // WARNING: Be careful if gps is flipped to false. The timers rely on gps being TRUE so it will cause the periodic checks to fail
                log.info("StudyMgr.checkSettings//gps changed from `\(study.studySettings?.gps)` to `\(deviceSettings.gps)`")
                study.studySettings?.gps = deviceSettings.gps
            }
            if (deviceSettings.gyro != study.studySettings?.gyro) {
                log.info("StudyMgr.checkSettings//gyro changed from `\(study.studySettings?.gyro)` to `\(deviceSettings.gyro)`")
                study.studySettings?.gyro = deviceSettings.gyro
            }
            if (deviceSettings.magnetometer != study.studySettings?.magnetometer) {
                log.info("StudyMgr.checkSettings//magnetometer changed from `\(study.studySettings?.magnetometer)` to `\(deviceSettings.magnetometer)`")
                study.studySettings?.magnetometer = deviceSettings.magnetometer
            }
            if (deviceSettings.powerState != study.studySettings?.powerState) {
                log.info("StudyMgr.checkSettings//powerState changed from `\(study.studySettings?.powerState)` to `\(deviceSettings.powerState)`")
                study.studySettings?.powerState = deviceSettings.powerState
            }
            if (deviceSettings.proximity != study.studySettings?.proximity) {
                log.info("StudyMgr.checkSettings//proximity changed from `\(study.studySettings?.proximity)` to `\(deviceSettings.proximity)`")
                study.studySettings?.proximity = deviceSettings.proximity
            }
            if (deviceSettings.reachability != study.studySettings?.reachability) {
                log.info("StudyMgr.checkSettings//reachability changed from `\(study.studySettings?.reachability)` to `\(deviceSettings.reachability)`")
                study.studySettings?.reachability = deviceSettings.reachability
            }
            return Recline.shared.save(study).asVoid();
        }.then { _ -> Promise<Bool> in
            _ = self.setNextSettingsTime()
            return Promise.value(true);
        }.recover { _ -> Promise<Bool> in
            return Promise.value(false);
        }
    }

    func setNextUploadTime() -> Promise<Bool> {
        guard let study = currentStudy, let studySettings = study.studySettings else {
            return Promise.value(true);
        }

        study.nextUploadCheck = Int64(Date().timeIntervalSince1970) + Int64(studySettings.uploadDataFileFrequencySeconds);
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return Promise.value(true);
        }
    }

    func setNextSurveyTime() -> Promise<Bool> {
        guard let study = currentStudy, let studySettings = study.studySettings else {
            return Promise.value(true);
        }

        study.nextSurveyCheck = Int64(Date().timeIntervalSince1970) + Int64(studySettings.checkForNewSurveysFreqSeconds)
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return Promise.value(true);
        }
    }

    func setNextSettingsTime() -> Promise<Bool> {
        guard let study = currentStudy, let studySettings = study.studySettings else {
            return Promise.value(true);
        }

        study.nextSettingsCheck = Int64(Date().timeIntervalSince1970) + Int64(study.settingsCheckFrequency);
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return Promise.value(true);
        }
    }

    func parseFilename(_ filename: String) -> (type: String, timestamp: Int64, ext: String){
        let url = URL(fileURLWithPath: filename)
        let pathExtention = url.pathExtension
        let pathPrefix = url.deletingPathExtension().lastPathComponent

        var type = ""

        let pieces = pathPrefix.split(separator: "_")
        var timestamp: Int64 = 0
        if (pieces.count > 2) {
            type = String(pieces[1])
            timestamp = Int64(String(pieces[pieces.count-1])) ?? 0
        }


        return (type: type, timestamp: timestamp, ext: pathExtention)
    }

    func purgeUploadData(_ fileList: [String:Int64], currentStorageUse: Int64) -> Promise<Void> {
        var used = currentStorageUse
        return Promise().then(on: DispatchQueue.global(qos: .default)) { _ -> Promise<Void> in
            log.error("EXCESSIVE STORAGE USED, used: \(currentStorageUse), WifiAvailable: \(self.appDelegate.reachability!.isReachableViaWiFi)")
            log.error("Last success: \(String(describing: self.currentStudy?.lastUploadSuccess))")
            for (filename, len) in fileList {
                log.error("file: \(filename), size: \(len)")
            }
            let keys = fileList.keys.sorted() { (a, b) in
                let fileA = self.parseFilename(a)
                let fileB = self.parseFilename(b)
                return fileA.timestamp < fileB.timestamp
            }

            for file in keys {
                let attrs = self.parseFilename(file)
                if (attrs.ext != "csv" || attrs.type.hasPrefix("survey")) {
                    log.info("Skipping deletion: \(file)")
                    continue
                }
                let filePath = DataStorageManager.uploadDataDirectory().appendingPathComponent(file);
                do {
                    log.warning("Removing file: \(filePath)")
                    try FileManager.default.removeItem(at: filePath);
                    used = used - fileList[file]!
                } catch {
                    log.error("Error removing file: \(filePath)")
                }

                if (used < self.MAX_UPLOAD_DATA) {
                    break
                }

            }

            //Crashlytics.sharedInstance().recordError(NSError(domain: "com.rf.beiwe.studies.excessive", code: 2, userInfo: nil))

            return Promise()
        }
    }

    func clearTempFiles() -> Promise<Void> {
        return Promise().then(on: DispatchQueue.global(qos: .default)) { _ -> Promise<Void> in
            do {
                let alamoTmpDir = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.alamofire.manager")!.appendingPathComponent("multipart.form.data")
                try FileManager.default.removeItem(at: alamoTmpDir)
            } catch {
                //log.error("Error removing tmp files: \(error)")
            }
            return Promise()
        }
    }

    func upload(_ processOnly: Bool) -> Promise<Void> {
        if (isUploading) {
            log.info("Already uploaded")
            return Promise();
        }
        log.info("Checking for uploads...");
        isUploading = true;

        var promiseChain: Promise<Bool>

        promiseChain = Recline.shared.compact().then { _ in
            DataStorageManager.sharedInstance.prepareForUpload()
        }.map { _ in
            log.info("prepareForUpload finished")
            return true
        }

        var numFiles = 0;
        var size: Int64 = 0
        var storageInUse: Int64 = 0
        let q = DispatchQueue.global(qos: .default)

        var filesToProcess: [String: Int64] = [:];
        return promiseChain.then(on: q) { (_: Bool) -> Promise<Bool> in
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(atPath: DataStorageManager.uploadDataDirectory().path)
            var uploadChain = Promise.value(true)
            if let enumerator = enumerator {
                while let filename = enumerator.nextObject() as? String {
                    if (DataStorageManager.sharedInstance.isUploadFile(filename)) {
                        let filePath = DataStorageManager.uploadDataDirectory().appendingPathComponent(filename);
                        let attr = try FileManager.default.attributesOfItem(atPath: filePath.path)
                        let fileSize = (attr[FileAttributeKey.size]! as AnyObject).longLongValue
                        filesToProcess[filename] = fileSize
                        size = size + fileSize!
                        //promises.append(promise);
                    }
                }
            }
            storageInUse = size
            if (!processOnly) {
                for (filename, len) in filesToProcess {
                    let filePath = DataStorageManager.uploadDataDirectory().appendingPathComponent(filename);
                    let uploadRequest = UploadRequest(fileName: filename, filePath: filePath.path);
                    uploadChain = uploadChain.then {_ -> Promise<Bool> in
                        log.info("Uploading: \(filename)")
                        return ApiManager.sharedInstance.makeMultipartUploadRequest(uploadRequest, file: filePath).then { _ -> Promise<Bool> in
                            log.info("Finished uploading: \(filename), removing.");
                            AppEventManager.sharedInstance.logAppEvent(event: "uploaded", msg: "Uploaded data file", d1: filename)
                            numFiles = numFiles + 1
                            try fileManager.removeItem(at: filePath);
                            storageInUse = storageInUse - len
                            filesToProcess.removeValue(forKey: filename)
                            return Promise.value(true);
                        }
                    }.recover { error -> Promise<Bool> in
                        AppEventManager.sharedInstance.logAppEvent(event: "upload_file_failed", msg: "Failed Uploaded data file", d1: filename)
                        return Promise.value(true)
                    }
                }
                return uploadChain
            } else {
                log.info("Skipping upload, processing only")
                return Promise.value(true)
            }
        }.then { (results: Bool) -> Promise<Void> in
            log.info("OK uploading \(numFiles). \(results)");
            log.info("Total Size of uploads: \(size)")
            AppEventManager.sharedInstance.logAppEvent(event: "upload_complete", msg: "Upload Complete", d1: String(numFiles))
            if let study = self.currentStudy {
                study.lastUploadSuccess = Int64(NSDate().timeIntervalSince1970)
                return Recline.shared.save(study).asVoid()
            } else {
                return Promise()
            }
        }.recover { error -> Void in
            log.info("Recover")
            AppEventManager.sharedInstance.logAppEvent(event: "upload_incomplete", msg: "Upload Incomplete", d1: String(storageInUse))
        }.then { () -> Promise<Void> in
            log.info("Size left after upload: \(storageInUse)")
            if (storageInUse > self.MAX_UPLOAD_DATA) {
                AppEventManager.sharedInstance.logAppEvent(event: "purge", msg: "Purging too large data files", d1: String(storageInUse))
                return self.purgeUploadData(filesToProcess, currentStorageUse: storageInUse)
            }
            else {
                return Promise()
            }
        }.then {
            return self.clearTempFiles()
        }.ensure {
            self.isUploading = false
            log.info("Always")
        }
    }
}
