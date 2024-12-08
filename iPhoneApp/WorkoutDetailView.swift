import SwiftUI
import HealthKit

struct WorkoutDetailView: View {
    var workout: HKWorkout
    @State private var splits: [SplitData] = []
    @State private var isLoading = true
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ZStack {
                    Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                    VStack {
                        Spacer()
                        ProgressView("loading run :)")
                            .padding()
                        Spacer()
                    }
                }
            } else if splits.isEmpty {
                ZStack {
                    Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                    VStack {
                        Spacer()
                        Text("No data available")
                            .padding()
                        Spacer()
                    }
                }
            } else {
                List {
                    Section(header:
                        HStack {
                            Text(formattedDate(from: workout.startDate)) // Use the inline formatter
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .padding(.vertical, 20) // top and bottom
                                .padding(.bottom, 2) // below title text
                                .padding(.top, -20) // top adjustment
                                .foregroundColor(.black) // Set text color to black
                            Spacer()
                        }
                        .background(Color(UIColor.systemGroupedBackground))
                        .listRowInsets(EdgeInsets()) // Remove default padding
                    ) {
                        HStack {
                            Text("km")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, -10) // left
                            Text("Avg Pace")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, -5) // left
                            Text("Avg HR")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, -10) // right
                        }
                        .font(.headline)
                        .padding(.top, -10) // top adjustment
                        .padding([.top, .leading, .trailing])
                        
                        ForEach(Array(splits.enumerated()), id: \.element.id) { index, split in
                            HStack {
                                Text("\(index + 1)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(split.paceString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(String(format: "%.0f", split.heartRate))")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding([.leading, .trailing, .vertical], 8)
                        }
                    }
                    .textCase(nil) // Removes the automatic uppercasing applied by List section headers
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            workoutManager.fetchWorkoutDetails(workout: workout) { fetchedSplits in
                // Exclude the last split if it is less than 0.1 km
                if let lastSplit = fetchedSplits.last, lastSplit.distance < 100 {
                    self.splits = Array(fetchedSplits.dropLast())
                } else {
                    self.splits = fetchedSplits
                }
                self.isLoading = false
            }
        }
    }

    // Direct formatting function for the full date
    func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

