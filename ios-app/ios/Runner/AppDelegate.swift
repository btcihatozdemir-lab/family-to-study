import UIKit
import Flutter
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 7/24 Arkaplan Ses ve Sessiz Butonunu Diken Alarm Oturumu
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers, .allowAirPlay, .allowBluetooth]
      )
      try audioSession.setActive(true)
    } catch {
      print("[AppDelegate] AVAudioSession yapılandırma hatası: \(error)")
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
