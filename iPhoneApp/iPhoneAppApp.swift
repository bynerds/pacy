import SwiftUI

@main
struct iPhoneAppApp: App {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .onOpenURL { url in
                    print("Received URL: \(url.absoluteString)")

                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       let queryItems = components.queryItems {

                        print("Query items: \(queryItems)")

                        let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value
                        let refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value
                        let expiresAt = queryItems.first(where: { $0.name == "expires_at" })?.value

                        if let accessToken = accessToken, !accessToken.isEmpty,
                           let refreshToken = refreshToken, !refreshToken.isEmpty,
                           let expiresAt = expiresAt, !expiresAt.isEmpty {

                            // Store the tokens in UserDefaults for later use
                            UserDefaults.standard.set(accessToken, forKey: "strava_access_token")
                            UserDefaults.standard.set(refreshToken, forKey: "strava_refresh_token")
                            UserDefaults.standard.set(expiresAt, forKey: "strava_expires_at")

                            print("Access token received: \(accessToken)")

                            // Close Safari OAuth flow and update UI
                            NotificationCenter.default.post(name: .didReceiveAuthCode, object: nil)
                        } else {
                            print("Failed to retrieve tokens from the URL")
                        }
                    } else {
                        print("Failed to parse URL")
                    }
                }
        }
    }
}

