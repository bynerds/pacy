import SwiftUI

struct MaxPulseView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.presentationMode) var presentationMode  // Used to programmatically dismiss the view
    @State private var maxPulseInput: String = ""
    @State private var isSaving = false  // Tracks if the save is in progress
    @State private var saveComplete = false  // Tracks if the save is complete

    var body: some View {
        VStack {
            Text("Set Max HR")
                .font(.headline)
                .padding()

            // TextField to input max pulse (integer)
            TextField("Enter Max HR", text: $maxPulseInput)
                .padding()

            Button(action: {
                saveMaxPulse()  // Trigger save process
            }) {
                if isSaving {
                    // Show spinner inside the button
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if saveComplete {
                    // Show "Saved" text after the save is complete
                    Text("Saved")
                        .foregroundColor(.green)
                        .fontWeight(.regular)
                } else {
                    // Default button label
                    Text("Save")
                        .fontWeight(.regular)
                }
            }
            .padding()
            .disabled(isSaving)  // Disable button while saving
        }
        .onAppear {
            // Load the current max pulse when the view appears
            maxPulseInput = "\(workoutManager.maxPulse)"
        }
    }

    // Method for saving max pulse
    private func saveMaxPulse() {
        guard let maxPulse = Int(maxPulseInput), maxPulse > 0 else {
            return  // Early return if input is invalid
        }
        
        isSaving = true  // Start showing the spinner
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Simulate a save operation and completion
            workoutManager.maxPulse = maxPulse  // Update the max pulse in WorkoutManager
            workoutManager.saveMaxPulse()       // Save the updated max pulse to UserDefaults
            
            isSaving = false  // Stop spinner
            saveComplete = true  // Show "Saved" in the button
            
            // Go back to the StartView after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentationMode.wrappedValue.dismiss()  // Automatically go back to the previous view
            }
        }
    }
}

struct MaxPulseView_Previews: PreviewProvider {
    static var previews: some View {
        MaxPulseView().environmentObject(WorkoutManager())
    }
}


