import Foundation

enum AppConfig {
  /// Render-hosted frontend base URL.
  /// Must be HTTPS.
  static let renderBaseURL = URL(string: "https://adnan-backend-v4.onrender.com")!

  /// Allowlist the domains your WKWebView is permitted to navigate to.
  /// Keep this strict for production.
  static let allowedHosts: Set<String> = [
    renderBaseURL.host ?? "",
  ]

  static let bridgeVersion = 1

  static var appBuildString: String {
    let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    if let ver, let build { return "\(ver)(\(build))" }
    return ver ?? (build ?? "")
  }

  static var deviceLocaleTag: String {
    Locale.current.identifier
  }
}
