import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
      [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCuK_kvIhsnS4yNgybNgeiCUy3fO_arL9g")

    GeneratedPluginRegistrant.register(with: self)

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }
}