import SwiftUI
import HealthKit
import Charts
import SafariServices

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var isLoading = true // Track loading state
    @State private var splits: [SplitData] = [] // Store splits
    @State private var isAuthenticated = false // Track Strava authentication
    @State private var isWorkoutLogged = false // Track workout logging status
    @State private var showSafari = false // Control the OAuth flow

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Show Strava authentication button if not authenticated
                    if !isAuthenticated {
                        Button(action: {
                            authenticateWithStrava()
                        }) {
                            Text("Connect to Strava")
                                .font(.headline)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding()
                        .sheet(isPresented: $showSafari) {
                            SafariView(url: URL(string: "https://www.strava.com/oauth/authorize?client_id=137150&response_type=code&redirect_uri=https://bynerds.com/pacy/exchange_token/&approval_prompt=force&scope=read,read_all,profile:read_all,activity:write")!)
                        }
                    } else {
                        Text("Connected to Strava")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding()

                        // Display stored tokens for development purposes
                        if let accessToken = UserDefaults.standard.string(forKey: "strava_access_token"),
                           let refreshToken = UserDefaults.standard.string(forKey: "strava_refresh_token"),
                           let expiresAt = UserDefaults.standard.string(forKey: "strava_expires_at") {
                            VStack(spacing: 5) {
                                Text("Access Token: \(accessToken)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Refresh Token: \(refreshToken)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Expires At: \(expiresAt)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }

                        // Re-authenticate button
                        Button(action: {
                            // Clear stored tokens
                            UserDefaults.standard.removeObject(forKey: "strava_access_token")
                            UserDefaults.standard.removeObject(forKey: "strava_refresh_token")
                            UserDefaults.standard.removeObject(forKey: "strava_expires_at")

                            // Update the authenticated state and trigger the initial authentication flow
                            isAuthenticated = false // Reset authenticated state
                            authenticateWithStrava() // Trigger authentication
                        }) {
                            Text("Re-authenticate")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding()
                    }

                    // Show loading indicator while fetching workout
                    if isLoading {
                        VStack {
                            Spacer()
                            ProgressView("Loading last run...")
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                            Spacer()
                        }
                    } else if let lastWorkout = workoutManager.lastWorkout {
                        // Display workout data once it's fetched
                        VStack(alignment: .leading) {
                            WorkoutRow(workoutWithDetails: lastWorkout)
                                .environmentObject(workoutManager)
                        }
                        .padding()

                        // Show heart rate and pace charts if splits are available
                        if !splits.isEmpty {
                            Text("Heart Rate")
                                .font(.headline)
                            HeartRateChart(splits: splits)
                                .frame(height: 140)
                                .background(Color.white)
                                .padding(.top, 10)
                                .padding(.bottom, 20)

                            Text("Pace")
                                .font(.headline)
                            PaceChart(splits: splits)
                                .frame(height: 140)
                                .background(Color.white)
                                .padding(.top, 10)
                                .padding(.bottom, 20)

                            // Show the Log to Strava button only after Strava is connected and workout is fetched
                            if isAuthenticated {
                                Button(action: {
                                    workoutManager.logWorkoutToStrava(lastWorkout.workout) { success in
                                        isWorkoutLogged = success
                                    }
                                }) {
                                    Text("Log to Strava")
                                        .font(.headline)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding()
                                .alert(isPresented: $isWorkoutLogged) {
                                    Alert(title: Text(isWorkoutLogged ? "Success" : "Error"),
                                          message: Text(isWorkoutLogged ? "Workout logged to Strava!" : "Failed to log workout."))
                                }
                            }
                        } else {
                            Text("No splits available")
                                .padding()
                        }
                    } else {
                        Text("No recent workout available")
                            .font(.headline)
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("Last Workout")
        .environmentObject(workoutManager)
        .onAppear {
            fetchData()
            // Check for stored tokens on launch
            if UserDefaults.standard.string(forKey: "strava_access_token") != nil {
                isAuthenticated = true // Set to true if access token exists
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .didReceiveAuthCode)) { notification in
            self.showSafari = false // Close Safari OAuth flow

            // Mark the user as authenticated
            self.isAuthenticated = true
        }
    }

    // Fetch the workout and splits data, and manage loading state
    func fetchData() {
        isLoading = true
        workoutManager.fetchLastWorkout { success in
            if success, let workout = workoutManager.lastWorkout?.workout {
                workoutManager.fetchWorkoutDetails(workout: workout) { fetchedSplits in
                    if let lastSplit = fetchedSplits.last, lastSplit.distance < 200 {
                        self.splits = Array(fetchedSplits.dropLast())
                    } else {
                        self.splits = fetchedSplits
                    }
                    isLoading = false
                }
            } else {
                isLoading = false
            }
        }
    }

    // Trigger OAuth flow
    func authenticateWithStrava() {
        showSafari = true
    }
}

// Helper to present SafariView
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}

// Notification extension for receiving auth code
extension Notification.Name {
    static let didReceiveAuthCode = Notification.Name("didReceiveAuthCode")
}

// Define the WorkoutRow View
struct WorkoutRow: View {
    var workoutWithDetails: WorkoutWithDetails

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if let distance = workoutWithDetails.workout.totalDistance?.doubleValue(for: HKUnit.meter()) {
                    let roundedDistance = (distance / 1000).rounded()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(roundedDistance))")
                            .font(.system(size: 48, weight: .bold))
                        Text("km")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("0 km")
                        .font(.system(size: 48, weight: .bold))
                }

                if let elevation = workoutWithDetails.elevationAscended, elevation > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(elevation))")
                            .font(.system(size: 20, weight: .bold))
                        Text("m gain")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("0m gain")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 120, alignment: .leading)

            Divider().frame(height: 60)

            VStack(alignment: .leading, spacing: 8) {
                if let avgPace = workoutWithDetails.avgPace {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(avgPace)
                            .font(.system(size: 32, weight: .bold))
                        Text("avg pace")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("N/A pace")
                        .font(.system(size: 32, weight: .bold))
                }

                if let avgHeartRate = workoutWithDetails.avgHeartRate {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(avgHeartRate))")
                            .font(.system(size: 32, weight: .bold))
                            .padding(.trailing, 3)
                        Text("avg HR")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gray)

                        Text("\(Int(avgHeartRate / 200 * 100))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("N/A HR")
                        .font(.system(size: 32, weight: .bold))
                }
            }
            .padding(.top, 11)
        }
        .padding(.vertical, 8)
    }
}

// HeartRateChart struct
struct HeartRateChart: View {
    var splits: [SplitData]

    var body: some View {
        let minHeartRate = 100.0
        let maxHeartRateFromData = splits.map { $0.heartRate }.max() ?? 200
        let maxHeartRate = maxHeartRateFromData * 1.25

        HStack(alignment: .top) {
            Chart {
                ForEach(Array(splits.enumerated()), id: \.element.id) { index, split in
                    LineMark(
                        x: .value("Km", index + 1),
                        y: .value("Heart Rate", split.heartRate)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(Color(red: 1.0, green: 0.17, blue: 0.33))
                    .symbol(Circle())
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: Array(1...splits.count)) { value in
                    AxisGridLine()
                    AxisValueLabel() {
                        if let km = value.as(Int.self), km != 0 {
                            Text("\(km)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .chartYScale(domain: [minHeartRate, maxHeartRate])
            .frame(height: 140)

            Spacer().frame(width: 15)
        }
        .background(Color.white)
    }
}

// PaceChart struct
struct PaceChart: View {
    var splits: [SplitData]

    var body: some View {
        let minPace = splits.map { $0.pace }.min() ?? 200
        let maxPace = splits.map { $0.pace }.max() ?? 400

        let minPaceThreshold = min(minPace, 200)
        let maxPaceThreshold = maxPace * 1.2

        let yAxisValues = stride(from: minPaceThreshold, to: maxPaceThreshold, by: 50).map { $0 }

        HStack(alignment: .top) {
            Chart {
                ForEach(Array(splits.enumerated()), id: \.element.id) { index, split in
                    LineMark(
                        x: .value("Km", index + 1),
                        y: .value("Pace", split.pace)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(Color(red: 0.0, green: 0.0, blue: 0.0))
                    .symbol(Circle())
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: yAxisValues) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let paceInSeconds = value.as(Double.self) {
                            Text(paceString(from: paceInSeconds))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: Array(1...splits.count)) { value in
                    AxisGridLine()
                    AxisValueLabel() {
                        if let km = value.as(Int.self), km != 0 {
                            Text("\(km)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .chartYScale(domain: [minPaceThreshold, maxPaceThreshold])
            .frame(height: 140)

            Spacer().frame(width: 5)
        }
        .background(Color.white)
    }

    func paceString(from seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d'%02d''", minutes, remainingSeconds)
    }
}

