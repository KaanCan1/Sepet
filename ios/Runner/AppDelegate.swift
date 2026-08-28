import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Aylık kart bildirimi uygulama önplandayken de görünsün ve dokunuş
    // Flutter tarafına ulaşsın. FlutterAppDelegate zaten UNUserNotification
    // temsilcisi; atama yapılmazsa önplanda bildirim sessizce yutuluyor.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Cihaz üstü OCR: Apple Vision üzerinden.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SepetOcr") {
      OcrPlugin.register(with: registrar)
    }
  }
}
