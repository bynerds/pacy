import CoreMotion
import Foundation
import HealthKit

@MainActor
class WorkoutManager: NSObject, ObservableObject {
    // Published property for maxPulse, with UserDefaults persistence
    @Published var maxPulse: Int = UserDefaults.standard.integer(forKey: "maxPulse") != 0 ? UserDefaults.standard.integer(forKey: "maxPulse") : 200

    var selectedWorkout: HKWorkoutActivityType? {
        didSet {
            if selectedWorkout != nil {
                self.requestMotionAndFitnessPermission()
            }
        }
    }

    @Published var showingSummaryView: Bool = false {
        didSet {
            DispatchQueue.main.async { [self] in
                if showingSummaryView == false {
                    resetWorkout()
                }
            }
        }
    }

    @Published var elevationAscended: Double = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var durationLast3Km: Double = 0
    @Published var distanceLast3Km: Double = 0
    @Published var workout: HKWorkout?
    @Published var running: Bool = false

    private let altimeter = CMAltimeter()
    private var startingAltitude: Double?

    private var lastElapsedTime: TimeInterval = 0
    private var distancesWithDurations: [DistanceWithDuration] = []
    private var heartRateSamples: [Double] = []

    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?

    // Save the maxPulse value
    func saveMaxPulse() {
        UserDefaults.standard.set(self.maxPulse, forKey: "maxPulse")
    }

    func startWorkout(workoutType: HKWorkoutActivityType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            session?.delegate = self
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { [weak self] success, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if success {
                        self.totalDuration = 0
                        self.distanceLast3Km = 0
                        self.durationLast3Km = 0
                        self.running = true
                        self.startAltitudeUpdatesViaMotionManager()
                    }
                }
            }
        } catch {
            print("An error occurred setting up the workout session: \(error.localizedDescription)")
        }
    }

    private func startAltitudeUpdatesViaMotionManager() {
        // Ensure altimeter is available
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }

        altimeter.startRelativeAltitudeUpdates(to: .main) { altitudeData, error in
            guard error == nil else {
                print("Error starting altitude updates: \(error!.localizedDescription)")
                return
            }
            if let relativeAltitude = altitudeData?.relativeAltitude.doubleValue {
                DispatchQueue.main.async {
                    if self.startingAltitude == nil {
                        self.startingAltitude = relativeAltitude
                    } else if let startAltitude = self.startingAltitude {
                        let altitudeDifference = relativeAltitude - startAltitude
                        if altitudeDifference > 0 {
                            self.elevationAscended += altitudeDifference
                        }
                        self.startingAltitude = relativeAltitude
                    }
                }
            }
        }
    }

    func requestMotionAndFitnessPermission() {
        let status = CMAltimeter.authorizationStatus()
        
        switch status {
        case .notDetermined:
            let recorder = CMSensorRecorder()
            recorder.recordAccelerometer(forDuration: 0.1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startWorkoutIfPermitted()
            }
        case .restricted, .denied:
            print("Motion & Fitness permission is restricted or denied.")
        case .authorized:
            self.startWorkoutIfPermitted()
        @unknown default:
            fatalError("Unknown CMAltimeter authorization status.")
        }
    }

    private func startWorkoutIfPermitted() {
        if CMAltimeter.authorizationStatus() == .authorized {
            if let selectedWorkout = self.selectedWorkout {
                self.startWorkout(workoutType: selectedWorkout)
            }
        } else {
            print("Cannot start workout because Motion & Fitness permission is not granted.")
        }
    }

    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.activitySummaryType()
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if !success {
                print("Error requesting HealthKit authorization: \(String(describing: error))")
            }
        }
    }

    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }
        DispatchQueue.main.async {
            self.updateMetricsBasedOnStatistics(statistics)
        }
    }

    private func updateMetricsBasedOnStatistics(_ statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            if let newHeartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                DispatchQueue.main.async {
                    self.heartRate = newHeartRate
                    self.heartRateSamples.append(newHeartRate)
                    self.averageHeartRate = self.heartRateSamples.reduce(0, +) / Double(self.heartRateSamples.count)
                }
            }
        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), HKQuantityType.quantityType(forIdentifier: .distanceCycling):
            let meterUnit = HKUnit.meter()
            let newDistance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0
            let distanceDelta = newDistance - self.distance
            DispatchQueue.main.async {
                self.distance = newDistance
                self.updateDistanceAndDuration(distanceDelta: distanceDelta)
            }
        default: break
        }
    }

    private func updateDistanceAndDuration(distanceDelta: Double) {
        if let elapsedTime = builder?.elapsedTime {
            let durationDelta = elapsedTime - lastElapsedTime
            lastElapsedTime = elapsedTime
            DispatchQueue.main.async {
                self.totalDuration += durationDelta

                self.distanceLast3Km += distanceDelta
                self.durationLast3Km += durationDelta

                self.distancesWithDurations.append(DistanceWithDuration(distance: distanceDelta, duration: durationDelta))
                self.updateDuration()
            }
        }
    }

    private func updateDuration() {
        DispatchQueue.main.async {
            while self.distanceLast3Km > 3000 {
                if let first = self.distancesWithDurations.first {
                    self.distanceLast3Km -= first.distance
                    self.durationLast3Km -= first.duration
                    self.distancesWithDurations.removeFirst()
                }
            }
        }
    }

    func getAverageDurationString() -> String {
        guard distanceLast3Km != 0 else { return "0'00''" }
        let averageDuration = durationLast3Km / (distanceLast3Km / 1000.0)
        let seconds = Int(averageDuration.truncatingRemainder(dividingBy: 60))
        let minutes = Int((averageDuration / 60).truncatingRemainder(dividingBy: 60))
        return String(format: "%d'%02d''", minutes, seconds)
    }

    func getOverallAveragePace() -> String {
        guard distance > 0 else { return "0'00''" }
        let averagePace = totalDuration / (distance / 1000)
        let minutes = Int(averagePace / 60)
        let seconds = Int(averagePace.truncatingRemainder(dividingBy: 60))
        return String(format: "%d'%02d''", minutes, seconds)
    }

    func togglePause() {
        if running {
            pause()
        } else {
            resume()
        }
    }

    private func pause() {
        session?.pause()
        DispatchQueue.main.async {
            self.running = false
        }
    }

    private func resume() {
        session?.resume()
        DispatchQueue.main.async {
            self.running = true
        }
    }

    func endWorkout() {
        session?.end()
        altimeter.stopRelativeAltitudeUpdates()
        addElevationMetadata() // Ensure elevation is added when workout ends
        DispatchQueue.main.async {
            self.showingSummaryView = true
            self.running = false
        }
    }

    // Add elevation metadata to the workout
    private func addElevationMetadata() {
        let elevationQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: self.elevationAscended)
        let metadata: [String: Any] = [
            HKMetadataKeyElevationAscended: elevationQuantity
        ]
        builder?.addMetadata(metadata, completion: { success, error in
            if success {
                print("Elevation metadata added successfully")
            } else if let error = error {
                print("Error adding elevation metadata: \(error.localizedDescription)")
            }
        })
    }

    private func resetWorkout() {
        DispatchQueue.main.async { [self] in
            selectedWorkout = nil
            builder = nil
            workout = nil
            session = nil
            activeEnergy = 0
            averageHeartRate = 0
            heartRate = 0
            distance = 0
            lastElapsedTime = 0
            durationLast3Km = 0
            distanceLast3Km = 0
            distancesWithDurations = []
            heartRateSamples = []
            elevationAscended = 0
            startingAltitude = nil
            altimeter.stopRelativeAltitudeUpdates()
        }
    }
}

// Define the missing struct DistanceWithDuration
struct DistanceWithDuration {
    let distance: Double
    let duration: TimeInterval
}

extension WorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed with error: \(error.localizedDescription)")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            if toState == .ended {
                self.addElevationMetadata()
                self.builder?.endCollection(withEnd: date) { success, error in
                    if success {
                        self.builder?.finishWorkout { workout, error in
                            if let workout = workout {
                                self.workout = workout
                                self.showingSummaryView = true
                                self.running = false
                            }
                        }
                    }
                }
            }
        }
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        DispatchQueue.main.async {
            for type in collectedTypes {
                if let quantityType = type as? HKQuantityType {
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    self.updateForStatistics(statistics)
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("Workout event collected.")
    }
}


