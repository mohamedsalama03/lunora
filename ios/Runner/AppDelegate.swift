import Flutter
import FirebaseMessaging
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc
class AppDelegate:
  FlutterAppDelegate,
  FlutterImplicitEngineDelegate,
  MessagingDelegate
{
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
      !mapsApiKey.isEmpty,
      !mapsApiKey.hasPrefix("$(")
    {
      GMSServices.provideAPIKey(mapsApiKey)
    }
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken

    #if DEBUG
      print("APNs device token registered")
    #endif

    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    #if DEBUG
      print("APNs registration failed: \(error.localizedDescription)")
    #endif

    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    #if DEBUG
      print("Native FCM registration token received: \(fcmToken?.isEmpty == false)")
    #endif
  }
}
