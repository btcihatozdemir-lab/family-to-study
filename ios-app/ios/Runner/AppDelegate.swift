import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static var apnsToken: String?
  private static var apnsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // APNs MethodChannel Kurulumu
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.familytostudy.app/apns",
        binaryMessenger: controller.binaryMessenger
      )
      AppDelegate.apnsChannel = channel

      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "getApnsToken":
          result(AppDelegate.apnsToken)
        case "registerForRemoteNotifications":
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Doğrudan APNs kaydını başlat
    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let tokenString = tokenParts.joined()
    AppDelegate.apnsToken = tokenString

    AppDelegate.apnsChannel?.invokeMethod("onApnsToken", arguments: tokenString)
    print("[AppDelegate] 🚀 APNs Cihaz Tokenı başarıyla alındı: \(tokenString)")

    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[AppDelegate] ⚠️ APNs kayıt hatası: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
