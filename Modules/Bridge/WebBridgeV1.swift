import Foundation
import WebKit

final class WebBridgeV1: NSObject {
  private weak var webView: WKWebView?

  func attach(_ webView: WKWebView) {
    self.webView = webView
  }

  func install(into contentController: WKUserContentController) {
    contentController.add(self, name: "adnanBridge")

    // Best-effort telemetry for autoplay blocks.
    let js = """
    (function(){
      try {
        if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.adnanBridge) return;
        if (window.__adnanAutoplayProbeInstalled) return;
        window.__adnanAutoplayProbeInstalled = true;

        const post = (payload) => {
          try { window.webkit.messageHandlers.adnanBridge.postMessage(payload); } catch (e) {}
        };

        const origPlay = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function(){
          try {
            const p = origPlay.apply(this, arguments);
            if (p && typeof p.catch === 'function') {
              p.catch((err) => {
                post({ type: 'media_play_rejected', name: (err && err.name) || null, message: (err && err.message) || String(err || '') });
              });
            }
            return p;
          } catch (err) {
            post({ type: 'media_play_throw', name: (err && err.name) || null, message: (err && err.message) || String(err || '') });
            throw err;
          }
        };
      } catch (e) {}
    })();
    """;

    let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    contentController.addUserScript(script)
  }

  func submitFinalTranscript(utteranceId: String, text: String, lang: String?) {
    guard let webView else { return }
    let payload: [String: Any] = [
      "utteranceId": utteranceId,
      "text": text,
      "lang": lang as Any,
      "capturedAtMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    Self.callAdnanBridge(webView: webView, method: "submitFinalTranscript", payload: payload)
  }

  func updatePartialTranscript(utteranceId: String, text: String, lang: String?) {
    guard let webView else { return }
    let payload: [String: Any] = [
      "utteranceId": utteranceId,
      "text": text,
      "lang": lang as Any,
      "capturedAtMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    Self.callAdnanBridge(webView: webView, method: "updatePartialTranscript", payload: payload)
  }

  static func callAdnanBridge(webView: WKWebView, method: String, payload: [String: Any]) {
    guard JSONSerialization.isValidJSONObject(payload) else { return }
    let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [])
    guard let jsonData, let json = String(data: jsonData, encoding: .utf8) else { return }

    let js = "(function(){try{var b=window.AdnanBridgeV1; if(!b||!b.\(method)) return; return b.\(method)(\(json));}catch(e){return;}})();"
    webView.evaluateJavaScript(js, completionHandler: nil)
  }

  static func callAdnanBridgeWithRetry(webView: WKWebView, method: String, payload: [String: Any]) {
    guard JSONSerialization.isValidJSONObject(payload) else { return }
    let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [])
    guard let jsonData, let json = String(data: jsonData, encoding: .utf8) else { return }

    let js = """
    (function(){
      try {
        var attempts = 0;
        var payload = \(json);
        var tick = function(){
          attempts++;
          try {
            var b = window.AdnanBridgeV1;
            if (b && typeof b.\(method) === 'function') {
              b.\(method)(payload);
              return;
            }
          } catch (e) {}
          if (attempts < 20) setTimeout(tick, 100);
        };
        tick();
      } catch (e) {}
    })();
    """;

    webView.evaluateJavaScript(js, completionHandler: nil)
  }
}

extension WebBridgeV1: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.name == "adnanBridge" {
      _ = message.body
    }
  }
}
