import AVFoundation
import Foundation

@MainActor
final class AudioSessionController: ObservableObject {
  private let session = AVAudioSession.sharedInstance()

  func activatePlayAndRecord() async {
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetooth]
      )
      try session.setActive(true, options: [])
    } catch {
      // Intentionally silent; UI layer can surface if needed.
    }
  }

  func deactivate() async {
    do {
      try session.setActive(false, options: [])
    } catch {
      // ignore
    }
  }
}
