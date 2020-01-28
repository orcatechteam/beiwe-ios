/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import HealthKit

class HealthKitAssistant {
  
  private enum HealthkitError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
  }
  
  class func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {
    
    //1. Check to see if HealthKit Is Available on this device
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(false, HealthkitError.notAvailableOnDevice)
      return
    }

    //2. Prepare the data types that will interact with HealthKit
    // - Characteristic identifiers
    guard   let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
            let bloodType = HKObjectType.characteristicType(forIdentifier: .bloodType),
            //let fitzpatrickSkinType = HKObjectType.quantityType(forIdentifier: .fitzpatrickSkinType),
            //let wheelChairUse = HKObjectType.quantityType(forIdentifier: .wheelChairUse),
            let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) else {
            
                completion(false, HealthkitError.dataTypeNotAvailable)
                return
    }
    
    // - Body Measurements
    //let waistCercumference = HKObjectType.quantityType(forIdentifier: .waistCercumference)
    guard   let height = HKObjectType.quantityType(forIdentifier: .height),
            let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
            let bodyMassIndex = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
            let leanBodyMass = HKObjectType.quantityType(forIdentifier: .leanBodyMass),
            let bodyFatPercentage = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) else {
                       
               completion(false, HealthkitError.dataTypeNotAvailable)
               return
       }
    
    // - Vital Signs
    //let lowHeartRateEvent = HKObjectType.quantityType(forIdentifier: .lowHeartRateEvent),
    //let highHeartRateEvent = HKObjectType.quantityType(forIdentifier: .highHeartRateEvent),
    //let irregularHeartRhythmEvent = HKObjectType.quantityType(forIdentifier: .irregularHeartRhythmEvent),
    //let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
    //let heartRateVariabilitySDNN = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
    //let walkingHeartRateAverage = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage),
    //let oxygenSaturation = HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
    //let bodyTemperature = HKObjectType.quantityType(forIdentifier: .bodyTemperature),
    //let bloodPressure = HKObjectType.quantityType(forIdentifier: .bloodPressure),
    //let bloodPressureSystolic = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
    //let respitoryRate = HKObjectType.quantityType(forIdentifier: .respitoryRate),
    //let vo2Max = HKObjectType.quantityType(forIdentifier: .vo2Max)
    guard   let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            
                completion(false, HealthkitError.dataTypeNotAvailable)
                return
        }
    
    // - Lab and Test Results
    guard   let bloodAlcoholContent = HKObjectType.quantityType(forIdentifier: .bloodAlcoholContent),
            let bloodGlucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose),
            let electrodermalActivity = HKObjectType.quantityType(forIdentifier: .electrodermalActivity),
            let forcedExpiratoryVolume1 = HKObjectType.quantityType(forIdentifier: .forcedExpiratoryVolume1),
            //let forceVitalCapacity = HKObjectType.quantityType(forIdentifier: .forceVitalCapacity),
            let inhalerUsage = HKObjectType.quantityType(forIdentifier: .inhalerUsage),
            //let insulinDelivery = HKObjectType.quantityType(forIdentifier: .insulinDelivery),
            let numberOfTimesFallen = HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen),
            let peakExpiratoryFlowRate = HKObjectType.quantityType(forIdentifier: .peakExpiratoryFlowRate),
            let peripheralPerfusionIndex = HKObjectType.quantityType(forIdentifier: .peripheralPerfusionIndex)  else {
                
                completion(false, HealthkitError.dataTypeNotAvailable)
                return
        }
        
    // - Mindfulness and Sleep
 /*   guard   let sleepAnalysis = HKObjectType.quantityType(forIdentifier: .sleepAnalysis) else {
            
            completion(false, HealthkitSetupError.dataTypeNotAvailable)
            return
    }
  */
    // - Activity
    // let pushCount = HKObjectType.quantityType(forIdentifier: .pushCount),
    // let distanceWheelchair = HKObjectType.quantityType(forIdentifier: .distanceWheelchair),
    // let swimmingStrokeCount = HKObjectType.quantityType(forIdentifier: .swimmingStrokeCount),
    // let distanceSwimming = HKObjectType.quantityType(forIdentifier: .distanceSwimming),
    // let distanceDownhillSnowSports = HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports),
    // let appleStandHour = HKObjectType.quantityType(forIdentifier: .appleStandHour),
    // let appleStandTime = HKObjectType.quantityType(forIdentifier: .appleStandTime)
    guard   let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
            let distanceWalkingRunning = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            let distanceCycling = HKObjectType.quantityType(forIdentifier: .distanceCycling),
            
            let basalEnergyBurned = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned),
            let activeEnergyBurned = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let flightsClimbed = HKObjectType.quantityType(forIdentifier: .flightsClimbed),
            let appleExerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            
            completion(false, HealthkitError.dataTypeNotAvailable)
            return
    }
    
    // - UV Exposure
    guard   let uvExposure = HKObjectType.quantityType(forIdentifier: .uvExposure) else {
            
            completion(false, HealthkitError.dataTypeNotAvailable)
            return
    }
    
    // - Audio Exposure
    /*
    guard   let audioExposureEvent = HKObjectType.quantityType(forIdentifier: .audioExposureEvent),
            let environmentsAudioExposure = HKObjectType.quantityType(forIdentifier: .environmentsAudioExposure),
            let headphoneAudioExposure = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else {
                
                completion(false, HealthkitSetupError.dataTypeNotAvailable)
                return
        }
    */
    
    // - Self Care
    /*
    guard   let toothbrushingEvent = HKObjectType.quantityType(forIdentifier: .toothbrushingEvent) else {
                
                completion(false, HealthkitSetupError.dataTypeNotAvailable)
                return
        }
    */
    
    //3. Prepare a list of types you want HealthKit to read and write
    let healthKitTypesToRead: Set<HKObjectType> = [
        dateOfBirth,
        bloodType,
        biologicalSex,
        bodyMassIndex,
        height,
        bodyMass,
        leanBodyMass,
        bodyFatPercentage,
        //waistCercumference
        //sleepAnalysis,
        uvExposure,
        //pushCount,
        distanceCycling,
        stepCount,
        distanceWalkingRunning,
        //distanceWheelchair,
        //swimmingStrokeCount,
        //distanceSwimming,
        //distanceDownhillSnowSports,
        basalEnergyBurned,
        activeEnergyBurned,
        flightsClimbed,
        appleExerciseTime,
        //appleStandHour,
        //toothbrushingEvent,
        //appleStandTime,
        //audioExposureEvent,
        //environmentsAudioExposure,
        //headphoneAudioExposure,
        bloodAlcoholContent,
        bloodGlucose,
        electrodermalActivity,
        forcedExpiratoryVolume1,
        //forceVitalCapacity,
        inhalerUsage,
        //insulinDelivery,
        numberOfTimesFallen,
        peakExpiratoryFlowRate,
        peripheralPerfusionIndex,
        heartRate,
        //lowHeartRateEvent,
        //highHeartRateEvent,
        //irregularHeartRhythmEvent,
        //restingHeartRate,
        //heartRateVariabilitySDNN,
        //walkingHeartRateAverage,
        //oxygenSaturation,
        //bodyTemperature,
        //bloodPressure,
        //bloodPressureSystolic,
        //respitoryRate,
        //vo2Max,
        HKObjectType.workoutType()]
    
    //3. Request Authorization
    HKHealthStore().requestAuthorization(toShare: [],
                                         read: healthKitTypesToRead) { (success, error) in
      completion(success, error)
    }
  }
}
