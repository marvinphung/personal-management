import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var widgetChannel: FlutterMethodChannel?
  private var initialUrl: URL?
  private let appGroupId = "group.app.quanlytao.user"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      initialUrl = url
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureWidgetChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.quanlytao.user/widget", binaryMessenger: binaryMessenger)
    self.widgetChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
        return
      }

      let defaults = UserDefaults(suiteName: self.appGroupId)

      switch call.method {
      case "updateWidgetCount":
        let args = call.arguments as? [String: Any]
        let count = args?["count"] as? Int ?? 0
        let generation = args?["generation"] as? Int
        let owner = args?["owner"] as? String
        let currentGen = defaults?.integer(forKey: "session_generation") ?? 0
        if let incomingGen = generation, incomingGen < currentGen {
          result(true)
          return
        }
        defaults?.set(max(0, count), forKey: "pending_count")
        if let generation = generation {
          defaults?.set(generation, forKey: "session_generation")
        }
        if let owner = owner {
          defaults?.set(owner, forKey: "session_owner")
        }
        defaults?.set(false, forKey: "is_stale")
        defaults?.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: "last_updated_epoch_ms")
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(true)

      case "setWidgetCredentials":
        let args = call.arguments as? [String: Any]
        let token = args?["token"] as? String ?? ""
        let baseUrl = args?["baseUrl"] as? String ?? ""
        let generation = args?["generation"] as? Int
        let owner = args?["owner"] as? String
        defaults?.set(token, forKey: "widget_token")
        defaults?.set(baseUrl, forKey: "base_url")
        if let generation = generation {
          defaults?.set(generation, forKey: "session_generation")
        }
        if let owner = owner {
          defaults?.set(owner, forKey: "session_owner")
        }
        defaults?.set(false, forKey: "is_stale")
        defaults?.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: "last_updated_epoch_ms")
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(true)

      case "clearWidget":
        defaults?.removeObject(forKey: "pending_count")
        defaults?.removeObject(forKey: "widget_token")
        defaults?.removeObject(forKey: "base_url")
        defaults?.removeObject(forKey: "last_updated_epoch_ms")
        defaults?.removeObject(forKey: "last_error")
        defaults?.removeObject(forKey: "session_generation")
        defaults?.removeObject(forKey: "session_owner")
        defaults?.removeObject(forKey: "is_stale")
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(true)

      case "getInitialRoute":
        if let url = self.initialUrl, url.scheme == "quanlytao", url.host == "bank-inbox" {
          self.initialUrl = nil
          result("/pending")
        } else {
          result(nil)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

  }

  func handleUrl(_ url: URL) {
    if url.scheme == "quanlytao" && url.host == "bank-inbox" {
      if let channel = widgetChannel {
        channel.invokeMethod("onDeepLink", arguments: "/pending")
      } else {
        initialUrl = url
      }
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    handleUrl(url)
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureWidgetChannel(binaryMessenger: engineBridge.applicationRegistrar.messenger())
  }
}
