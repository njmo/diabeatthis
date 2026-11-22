import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let caregiverWatch = CaregiverWatchBridge()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    caregiverWatch.activate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    caregiverWatch.connect(engineBridge.applicationRegistrar.messenger())
  }
}

private final class CaregiverWatchBridge: NSObject, WCSessionDelegate {
  private var channel: FlutterMethodChannel?

  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func connect(_ messenger: FlutterBinaryMessenger) {
    guard WCSession.isSupported() else { return }
    let channel = FlutterMethodChannel(name: "pl.diabeatthis.app/meal_decision_watch", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      // Wear-only requests made by the shared runtime have no iOS implementation.
      if call.method == "inboxChanged" {
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    DispatchQueue.main.async { [weak self] in
      guard let channel = self?.channel else {
        replyHandler(["status": "unavailable"])
        return
      }
      channel.invokeMethod("exchangeAppleWatchCaregiver", arguments: message) { response in
        // WatchConnectivity accepts property-list values. JSON Data preserves
        // nulls in the existing Dart protocol without altering its wire format.
        guard let response = response as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: response) else {
          replyHandler(["status": "unavailable"])
          return
        }
        replyHandler(["payload": data])
      }
    }
  }
}
