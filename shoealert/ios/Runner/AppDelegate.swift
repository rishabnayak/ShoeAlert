import UIKit
import Flutter
import beacon_monitoring

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    setupAppDelegateRegistry()
    setupBeaconMonitoringPluginCallback()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
  static func registerPlugins(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
  }
    
  private func setupAppDelegateRegistry() {
    AppDelegate.registerPlugins(with: self)
  }
    
  private func setupBeaconMonitoringPluginCallback() {
    BeaconMonitoringPlugin.setPluginRegistrantCallback { registry in
      AppDelegate.registerPlugins(with: registry)
    }
  }
}
