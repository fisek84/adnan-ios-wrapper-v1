import SwiftUI

struct RootView: View {
  @StateObject private var audioSession = AudioSessionController()
  @StateObject private var web = WebContainerViewModel()
  @StateObject private var speech = SpeechTranscriber()
  @State private var lastMediaPlayError: String? = nil

  var body: some View {
    ZStack(alignment: .bottom) {
      WebContainerView(viewModel: web)
        .ignoresSafeArea()

      ControlBar(
        isListening: speech.isListening,
        lastError: speech.lastError,
        lastMediaPlayError: lastMediaPlayError,
        onToggleListening: {
          Task { await toggleListening() }
        }
      )
      .padding(.bottom, 10)
      .padding(.horizontal, 12)
    }
    .task {
      await audioSession.activatePlayAndRecord()

      speech.onPartial = { utteranceId, text, langTag in
        web.updatePartialTranscript(utteranceId: utteranceId, text: text, lang: langTag)
      }
      speech.onFinal = { utteranceId, text, langTag in
        web.submitFinalTranscript(utteranceId: utteranceId, text: text, lang: langTag)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .adnanBridgeEvent)) { notif in
      let type = notif.userInfo?["type"] as? String
      guard type == "media_play_rejected" || type == "media_play_throw" else { return }
      let name = notif.userInfo?["name"] as? String
      let msg = notif.userInfo?["message"] as? String
      let suffix = [name, msg].compactMap { $0 }.joined(separator: ": ")
      lastMediaPlayError = suffix.isEmpty ? "Audio autoplay blocked" : "Audio autoplay blocked: \(suffix)"
    }
  }

  private func toggleListening() async {
    if speech.isListening {
      await speech.stop()
      return
    }

    await audioSession.activatePlayAndRecord()
    await speech.start()
  }
}

private struct ControlBar: View {
  let isListening: Bool
  let lastError: String?
  let lastMediaPlayError: String?
  let onToggleListening: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      if let lastError, !lastError.isEmpty {
        Text(lastError)
          .font(.footnote)
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.black.opacity(0.7))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      if let lastMediaPlayError, !lastMediaPlayError.isEmpty {
        Text(lastMediaPlayError)
          .font(.footnote)
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.black.opacity(0.7))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      HStack {
        Button(action: onToggleListening) {
          Text(isListening ? "Stop" : "Mic")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isListening ? Color.red : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        Spacer(minLength: 12)

        Text("Native STT → Web Bridge V1")
          .font(.footnote)
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.black.opacity(0.7))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}
