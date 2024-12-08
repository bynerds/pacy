import Foundation
import HealthKit

struct WorkoutWithDetails: Identifiable {
    let id: UUID
    let workout: HKWorkout
    var avgPace: String?
    var avgHeartRate: Double?
    var elevationAscended: Double?
}

struct SplitData: Identifiable {
    let id = UUID()
    var distance: Double = 0
    var duration: TimeInterval = 0
    var heartRate: Double = 0

    var pace: Double {
        return duration / (distance / 1000)
    }

    var paceString: String {
        let minutes = Int(pace / 60)
        let seconds = Int(pace.truncatingRemainder(dividingBy: 60))
        return String(format: "%d'%02d''", minutes, seconds)
    }
}

class WorkoutManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var lastWorkout: WorkoutWithDetails?
    private var cachedWorkoutDetails: [UUID: [SplitData]] = [:]

    init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        let typesToRead: Set = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            if !success {
                print("Authorization failed")
            }
        }
    }

    func fetchLastWorkout(completion: @escaping (Bool) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let workout = samples?.first as? HKWorkout else {
                completion(false)
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                self?.checkForDistanceSamples(workout: workout) { hasDistanceSamples in
                    if hasDistanceSamples && workout.duration >= 600 {
                        self?.processLastWorkout(workout) { success in
                            DispatchQueue.main.async {
                                completion(success)
                            }
                        }
                    } else {
                        completion(false)
                    }
                }
            }
        }
        healthStore.execute(query)
    }

    private func checkForDistanceSamples(workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let predicate = HKQuery.predicateForObjects(from: workout)

        let sampleQuery = HKSampleQuery(sampleType: distanceType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
            completion(samples?.count ?? 0 > 0)
        }

        healthStore.execute(sampleQuery)
    }

    private func processLastWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        fetchWorkoutDetails(workout: workout) { [weak self] _ in
            let avgPace = self?.averagePace(for: workout)
            let avgHeartRate = self?.averageHeartRate(for: workout)
            let elevationAscended = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter()) ?? 0

            DispatchQueue.main.async {
                self?.lastWorkout = WorkoutWithDetails(
                    id: workout.uuid,
                    workout: workout,
                    avgPace: avgPace,
                    avgHeartRate: avgHeartRate,
                    elevationAscended: elevationAscended
                )
                print("Processed and fetched details for the last workout")
                completion(true)
            }
        }
    }

    func fetchWorkoutDetails(workout: HKWorkout, completion: @escaping ([SplitData]) -> Void) {
        if let cachedData = cachedWorkoutDetails[workout.uuid] {
            completion(cachedData)
            return
        }

        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!

        let heartRateQuery = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 0, sortDescriptors: [sortDescriptor]) { [weak self] _, heartRateSamples, _ in
            guard let heartRateSamples = heartRateSamples as? [HKQuantitySample] else { return }
            print("Fetched \(heartRateSamples.count) heart rate samples")

            let distanceQuery = HKSampleQuery(sampleType: distanceType, predicate: predicate, limit: 0, sortDescriptors: [sortDescriptor]) { [weak self] _, distanceSamples, _ in
                guard let distanceSamples = distanceSamples as? [HKQuantitySample] else { return }
                print("Fetched \(distanceSamples.count) distance samples")

                var splits: [SplitData] = []
                var currentSplit = SplitData()
                var currentHeartRateSum = 0.0
                var currentHeartRateCount = 0

                for sample in distanceSamples {
                    let distance = sample.quantity.doubleValue(for: HKUnit.meter())
                    let startDate = sample.startDate
                    let endDate = sample.endDate
                    let duration = endDate.timeIntervalSince(startDate)

                    currentSplit.distance += distance
                    currentSplit.duration += duration

                    let heartRateSamplesInRange = heartRateSamples.filter { $0.startDate >= startDate && $0.endDate <= endDate }
                    let totalHeartRate = heartRateSamplesInRange.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) }
                    currentHeartRateSum += totalHeartRate
                    currentHeartRateCount += heartRateSamplesInRange.count

                    while currentSplit.distance >= 1000 {
                        let extraDistance = currentSplit.distance - 1000
                        let extraDuration = extraDistance * (currentSplit.duration / currentSplit.distance)

                        currentSplit.distance = 1000
                        currentSplit.duration -= extraDuration

                        if currentHeartRateCount > 0 {
                            currentSplit.heartRate = currentHeartRateSum / Double(currentHeartRateCount)
                        }

                        splits.append(currentSplit)
                        print("Added split: \(currentSplit)")

                        currentSplit = SplitData()
                        currentSplit.distance = extraDistance
                        currentSplit.duration = extraDuration
                        currentHeartRateSum = 0.0
                        currentHeartRateCount = 0
                    }
                }

                if currentSplit.distance > 0 {
                    if currentHeartRateCount > 0 {
                        currentSplit.heartRate = currentHeartRateSum / Double(currentHeartRateCount)
                    }
                    splits.append(currentSplit)
                }

                print("Fetched \(splits.count) splits")
                DispatchQueue.main.async {
                    self?.cachedWorkoutDetails[workout.uuid] = splits
                    completion(splits)
                }
            }
            self?.healthStore.execute(distanceQuery)
        }
        self.healthStore.execute(heartRateQuery)
    }

    func logWorkoutToStrava(_ workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        guard let accessToken = UserDefaults.standard.string(forKey: "strava_access_token") else {
            print("No Strava access token found")
            completion(false)
            return
        }
        
        let stravaURL = URL(string: "https://www.strava.com/api/v3/activities")!
        var request = URLRequest(url: stravaURL)
        request.httpMethod = "POST"

        // Prepare parameters to send to Strava
        let params: [String: Any] = [
            "name": "This is a \(Int(workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0) / 1000) km test run", // Dynamically create the name based on distance
            "type": "Run", // Type of activity
            "start_date_local": ISO8601DateFormatter().string(from: workout.startDate), // Local start date
            "elapsed_time": Int(workout.duration), // Duration in seconds
            "distance": workout.totalDistance?.doubleValue(for: .meter()) ?? 0, // Total distance in meters
            "description": "This is a \(Int(workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0) / 1000) km test run" // Description
        ]

        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Construct the body string like in the curl command
        let bodyString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to log workout:", error ?? "Unknown error")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }

        task.resume()
    }

    func averagePace(for workout: HKWorkout) -> String? {
        guard let totalDistance = workout.totalDistance?.doubleValue(for: HKUnit.meter()), totalDistance > 0 else { return nil }
        let totalTime = workout.duration
        let pace = totalTime / (totalDistance / 1000)
        let minutes = Int(pace / 60)
        let seconds = Int(pace.truncatingRemainder(dividingBy: 60))
        return String(format: "%d'%02d''", minutes, seconds)
    }

    func averageHeartRate(for workout: HKWorkout) -> Double? {
        guard let splits = cachedWorkoutDetails[workout.uuid], !splits.isEmpty else {
            return nil
        }
        let totalHeartRate = splits.reduce(0.0) { $0 + ($1.heartRate * $1.distance) }
        let totalDistance = splits.reduce(0.0) { $0 + $1.distance }
        return totalDistance > 0 ? totalHeartRate / totalDistance : nil
    }

    // Exchange auth code for access token
    func exchangeCodeForToken(authCode: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "https://bynerds.com/pacy/exchange_token/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let params: [String: Any] = [
            "client_id": "137150",
            "client_secret": "0e58996c4f885417f842ac359b36c726af90dbee",
            "code": authCode,
            "grant_type": "authorization_code"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to exchange code for token:", error ?? "Unknown error")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            // Parse the JSON response
            do {
                if let responseDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Response: \(responseDict)") // Debugging output

                    // Extract the access token
                    if let accessToken = responseDict["access_token"] as? String,
                       let refreshToken = responseDict["refresh_token"] as? String,
                       let expiresAt = responseDict["expires_at"] as? TimeInterval {
                        
                        // Store tokens in UserDefaults for later use
                        UserDefaults.standard.set(accessToken, forKey: "strava_access_token")
                        UserDefaults.standard.set(refreshToken, forKey: "strava_refresh_token")
                        UserDefaults.standard.set(expiresAt, forKey: "strava_expires_at")
                        
                        print("Access token received: \(accessToken)")
                        
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    } else {
                        print("Failed to parse tokens from response: \(responseDict)")
                        DispatchQueue.main.async {
                            completion(false)
                        }
                    }
                }
            } catch {
                print("Failed to parse JSON response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }

        task.resume()
    }
}


