import SwiftUI
import HealthKit

struct MetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        TabView {
            AllMetricsView()
                .environmentObject(workoutManager)
                .tabItem {
                    Text("All Metrics")
                }

            DistanceView()
                .environmentObject(workoutManager)
                .tabItem {
                    Text("Distance")
                }
            
            AveragePaceView()
                .environmentObject(workoutManager)
                .tabItem {
                    Text("Pace")
                }

            AverageDurationView()  // Same name as before
                .environmentObject(workoutManager)
                .tabItem {
                    Text("Duration")
                }
            
            HeartRateView()
                .environmentObject(workoutManager)
                .tabItem {
                    Text("Heart Rate")
                }
            
            DistanceView()
                .environmentObject(workoutManager)
                .tabItem {
                    Text("Distance")
                }
            
            AverageHeartRatePercentageView()
                .environmentObject(workoutManager)
                .tabItem {
                    Text("Avg HR %")
                }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .navigationBarHidden(true)
        .navigationTitle("")
    }
}

struct AllMetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                             isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workoutManager.getAverageDurationString())
                        .foregroundStyle(.yellow)
                        .font(.system(size: 30, weight: .regular, design: .rounded).monospacedDigit().lowercaseSmallCaps())
                        .padding(.vertical, -4)  // Adjust padding to reduce vertical space
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(workoutManager.getOverallAveragePace())
                        .font(.system(size: 30, weight: .regular, design: .rounded).monospacedDigit().lowercaseSmallCaps())
                        .padding(.vertical, -4)  // Adjust padding to reduce vertical space
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("HR \(String(format: "%.0f%%", (workoutManager.averageHeartRate / Double(workoutManager.maxPulse)) * 100))")
                        .font(.system(size: 30, weight: .regular, design: .rounded).monospacedDigit().lowercaseSmallCaps())
                        .padding(.vertical, -4)  // Adjust padding to reduce vertical space
                }
                Text("HR \(workoutManager.heartRate.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 30, weight: .regular, design: .rounded).monospacedDigit().lowercaseSmallCaps())
                    .padding(.vertical, -4)  // Adjust padding to reduce vertical space
                Text(String(format: "%.2f KM", workoutManager.distance / 1000))
                    .font(.system(size: 30, weight: .regular, design: .rounded).monospacedDigit().lowercaseSmallCaps())
                    .padding(.vertical, -4)  // Adjust padding to reduce vertical space
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }
}

struct DistanceView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                             isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .leading) {
                Text("Distance")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 1)
                
                Text(String(format: "%.2f KM", workoutManager.distance / 1000))
                    .font(.system(size: 40, weight: .regular, design: .default).monospacedDigit().lowercaseSmallCaps())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }
}

struct AveragePaceView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                             isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .leading) {
                Text("Avg Pace")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 1)
                
                Text(workoutManager.getOverallAveragePace())
                    .font(.system(size: 46, weight: .regular, design: .default).monospacedDigit().lowercaseSmallCaps())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }
}

struct AverageDurationView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                             isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .leading) {
                Text("Avg Pace Last 3km")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.yellow)
                    .padding(.bottom, 1)
                
                Text(workoutManager.getAverageDurationString())
                    .foregroundColor(.yellow)
                    .font(.system(size: 46, weight: .regular, design: .default).monospacedDigit().lowercaseSmallCaps())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }
}

struct HeartRateView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                             isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .leading) {
                Text("Current Heart Rate")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 1)
                
                Text("\(workoutManager.heartRate.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 46, weight: .regular, design: .default).monospacedDigit().lowercaseSmallCaps())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }
}

struct AverageHeartRatePercentageView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                             isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .leading) {
                Text("Avg Heart Rate")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 1)
                
                Text("\(String(format: "%.0f%%", (workoutManager.averageHeartRate / Double(workoutManager.maxPulse)) * 100))")
                    .font(.system(size: 46, weight: .regular, design: .default).monospacedDigit().lowercaseSmallCaps())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }
}

private struct MetricsTimelineSchedule: TimelineSchedule {
    var startDate: Date
    var isPaused: Bool

    init(from startDate: Date, isPaused: Bool) {
        self.startDate = startDate
        self.isPaused = isPaused
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var baseSchedule = PeriodicTimelineSchedule(from: self.startDate, by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0))
            .entries(from: startDate, mode: mode)
        
        return AnyIterator<Date> {
            guard !isPaused else { return nil }
            return baseSchedule.next()
        }
    }
}
