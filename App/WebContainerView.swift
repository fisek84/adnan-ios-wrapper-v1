import SwiftUI
import WebKit

final class WebContainerViewModel: ObservableObject {
  fileprivate let bridge = WebBridgeV1()

  func submitFinalTranscript(utteranceId: String, text: String, lang: String?) {
    bridge.submitFinalTranscript(utteranceId: utteranceId, text: text, lang: lang)
  }

  func updatePartialTranscript(utteranceId: String, text: String, lang: String?) {
    bridge.updatePartialTranscript(utteranceId: utteranceId, text: text, lang: lang)
  }
}

struct WebContainerView: UIViewRepresentable {
  @ObservedObject var viewModel: WebContainerViewModel

  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()

    config.allowsInlineMediaPlayback = true
    if #available(iOS 10.0, *) {
      config.mediaTypesRequiringUserActionForPlayback = []
    }

    let contentController = WKUserContentController()
    viewModel.bridge.install(into: contentController)
    config.userContentController = contentController

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator

    let req = URLRequest(url: AppConfig.renderBaseURL)
    webView.load(req)

    viewModel.bridge.attach(webView)

    return webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      if let host = navigationAction.request.url?.host,
         AppConfig.allowedHosts.contains(host) {
        decisionHandler(.allow)
        return
      }
      decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      let payload: [String: Any] = [
        "bridgeVersion": AppConfig.bridgeVersion,
        "runtime": "ios_wkwebview",
        "appBuild": AppConfig.appBuildString,
        "deviceLocale": AppConfig.deviceLocaleTag,
      ]
      WebBridgeV1.callAdnanBridgeWithRetry(webView: webView, method: "nativeHello", payload: payload)
    }
  }
}
