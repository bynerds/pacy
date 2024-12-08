import SwiftUI
import HealthKit

struct StartView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    var workoutTypes: [HKWorkoutActivityType] = [.running]

    var body: some View {
        VStack {
            // Workout Types List
            ForEach(workoutTypes) { workoutType in
                NavigationLink(workoutType.name, destination: SessionPagingView(),
                               tag: workoutType, selection: $workoutManager.selectedWorkout)
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 20, trailing: 5))
            }
        
            // Settings button
            NavigationLink("Settings", destination: MaxPulseView().environmentObject(workoutManager))
                .padding(EdgeInsets(top: 15, leading: 5, bottom: 0, trailing: 5))
        }
        .padding()  // Add padding to the entire VStack
        .background(Color.black)  // Set the entire background to black
        .navigationBarTitle("bynerds")
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView().environmentObject(WorkoutManager())
    }
}

extension HKWorkoutActivityType: Identifiable {
    public var id: UInt {
        rawValue
    }

    var name: String {
        switch self {
        case .running:
            return "Start Run"
        default:
            return ""
        }
    }
}

