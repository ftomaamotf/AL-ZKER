//
//  VoiceRecognitionManager.swift
//  Fathkoroni (On-Device Speech Recognition Auto-Switching)
//  التعرف الصوتي التلقائي وتغيير عنوان الذكر دون الحاجة لاستخدام Siri
//

import Foundation
import Speech
import AVFoundation

public final class VoiceRecognitionManager: NSObject, ObservableObject {
    public static let shared = VoiceRecognitionManager()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published public var isListening: Bool = false
    @Published public var lastSpokenPhrase: String = ""
    
    private override init() {
        super.init()
    }
    
    /// قم ببدء الاستماع المستمر على الساعة أو الهاتف دون سيري
    public func startContinuousListening() {
        guard !audioEngine.isRunning else { return }
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else { return }
            DispatchQueue.main.async {
                self.startAudioRecognitionSession()
            }
        }
    }
    
    public func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isListening = false
        }
    }
    
    private func startAudioRecognitionSession() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        // Use on-device recognition for watchOS performance & privacy
        if #available(iOS 13, watchOS 6.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                self.lastSpokenPhrase = text
                self.processSpokenTextForAutoSwitch(text)
            }
        }
    }
    
    /// التعرف الذكي على عبارات الذكر وتغيير عنوان الذكر تلقائياً دون أي تخصيص من المستخدم
    private func processSpokenTextForAutoSwitch(_ text: String) {
        let sync = WatchSyncService.shared
        var detectedZekr: String? = nil
        
        if text.contains("الله أكبر") || text.contains("الله اكبر") {
            detectedZekr = "الله أكبر"
        } else if text.contains("سبحان الله") {
            detectedZekr = "سبحان الله"
        } else if text.contains("الحمد لله") {
            detectedZekr = "الحمد لله"
        } else if text.contains("أستغفر الله") || text.contains("استغفر الله") {
            detectedZekr = "أستغفر الله"
        } else if text.contains("لا إله إلا الله") {
            detectedZekr = "لا إله إلا الله"
        } else if text.contains("لا حول ولا قوة") {
            detectedZekr = "لا حول ولا قوة إلا بالله"
        }
        
        if let newZekr = detectedZekr, newZekr != sync.currentZekr {
            DispatchQueue.main.async {
                // تبديل تلقائي فوري لعنوان الذكر وتصفير العداد للذكر الجديد
                sync.sendSyncPayload(count: 0, zekr: newZekr, target: sync.target)
            }
        }
    }
}
