import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechTranscriber: ObservableObject {
  @Published private(set) var isListening: Bool = false
  @Published private(set) var lastError: String? = nil

  var onPartial: ((String, String, String?) -> Void)?
  var onFinal: ((String, String, String?) -> Void)?

  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var recognizer: SFSpeechRecognizer?

  private var utteranceId: String = UUID().uuidString

  func start(locale: Locale = .current) async {
    lastError = nil

    let status = SFSpeechRecognizer.authorizationStatus()
    if status != .authorized {
      let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
        SFSpeechRecognizer.requestAuthorization { s in cont.resume(returning: s) }
      }
      if auth != .authorized {
        lastError = "Speech permission denied."
        return
      }
    }

    let micGranted = await requestMicPermission()
    if !micGranted {
      lastError = "Microphone permission denied."
      return
    }

    utteranceId = UUID().uuidString

    let localeId = locale.identifier
    recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))

    let req = SFSpeechAudioBufferRecognitionRequest()
    req.shouldReportPartialResults = true
    recognitionRequest = req

    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
      self?.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()

    do {
      try audioEngine.start()
    } catch {
      lastError = "Audio engine failed to start."
      cleanup()
      return
    }

    isListening = true

    recognitionTask = recognizer?.recognitionTask(with: req) { [weak self] result, error in
      guard let self else { return }
      if let error {
        Task { @MainActor in
          self.lastError = error.localizedDescription
          self.cleanup()
        }
        return
      }

      guard let result else { return }
      let txt = result.bestTranscription.formattedString
      let langTag = self.recognizer?.locale.identifier

      Task { @MainActor in
        if result.isFinal {
          self.onFinal?(self.utteranceId, txt, langTag)
          self.cleanup()
        } else {
          self.onPartial?(self.utteranceId, txt, langTag)
        }
      }
    }
  }

  func stop() async {
    cleanup()
  }

  private func cleanup() {
    isListening = false

    recognitionTask?.cancel()
    recognitionTask = nil

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    if audioEngine.isRunning {
      audioEngine.stop()
    }

    audioEngine.inputNode.removeTap(onBus: 0)
  }

  private func requestMicPermission() async -> Bool {
    await withCheckedContinuation { cont in
      AVAudioSession.sharedInstance().requestRecordPermission { ok in
        cont.resume(returning: ok)
      }
    }
  }
}
