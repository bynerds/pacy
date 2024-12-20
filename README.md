# Workout app for Apple Watch

Workout app built with HealthKit and SwiftUI.

## Overview

- Note: Project is inspired by sample code from WWDC21 session
[10009: Build a workout app for Apple Watch](https://developer.apple.com/wwdc21/10009/).

## Configure the sample code project

Before you run the sample code project in Xcode:

1. Open the sample with the latest version of Xcode.
2. Select the top-level project.
3. For the three targets, select the correct team in the Signing & Capabilities pane (next to Team) to let Xcode automatically manage your provisioning profile.
4. Make a note of the Bundle Identifier of the WatchKit App target.
5. Open the `Info.plist` file of the WatchKit Extension target, and change the value of the `NSExtension` > `NSExtensionAttributes` > `WKAppBundleIdentifier` key to the bundle ID you noted in the previous step.
6. Make a clean build and run the sample app on your device.

## Two targets, Watch and iPhone

1. The primary project is the Watch app, Pacy.
2. There is also a companion iPhone app that will be used to display last workout, and later implement support for logging (to Strava).