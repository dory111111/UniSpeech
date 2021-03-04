import Foundation
import Speech

public class SpeechRecognizer : NSObject {
    @objc static let sharedInstance: SpeechRecognizer = SpeechRecognizer()

    private var _unitySendMessageGameObjectName: String = "SpeechRecognizer"
    @objc var unitySendMessageGameObjectName: String {
        get {
            return _unitySendMessageGameObjectName
        }
        set {
            _unitySendMessageGameObjectName = newValue
        }
    }

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private override init() {
        super.init()
        speechRecognizer.delegate = self
    }

    @objc func requestRecognizerAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.unitySendMessage("OnAuthorized")
                    break
                    
                case .denied:
                    // User denied access to speech recognition
                    self.unitySendMessage("OnUnauthorized")
                    
                case .restricted:
                    // Speech recognition restricted on this device
                    self.unitySendMessage("OnUnauthorized")
                    
                case .notDetermined:
                    // Speech recognition not yet authorized
                    self.unitySendMessage("OnUnauthorized")
                }
            }
        }
    }

    @objc func startRecord() -> Bool {
        if audioEngine.isRunning {
            return false
        }
        try! startRecording()
        return true
    }

    @objc func stopRecord() -> Bool {
        if !audioEngine.isRunning {
            return false
        }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        return true
    }
    
    private func startRecording() throws {
        refreshTask()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSession.Category.record)
        try audioSession.setMode(AVAudioSession.Mode.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.unitySendMessage("OnRecognized", message: result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }
            
            if error != nil {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.unitySendMessage("OnError", message: error.debugDescription)
            }

            if isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.unitySendMessage("OnFinished",  message: result.bestTranscription.formattedString)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        try startAudioEngine()
    }

    private func refreshTask() {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
    }
    
    private func startAudioEngine() throws {
        audioEngine.prepare()
        try audioEngine.start()
    }

    @objc func unitySendMessage(_ methodName: String, message: String = "") {
        UnitySendMessage(self.unitySendMessageGameObjectName, methodName, message)
    }
}

extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    @objc public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if (available) {
            unitySendMessage("OnAvailable")
        } else {
            unitySendMessage("OnUnavailable")
        }
    }
}

