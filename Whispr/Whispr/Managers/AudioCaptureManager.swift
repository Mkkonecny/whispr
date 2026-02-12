//
//  AudioCaptureManager.swift
//  Whispr
//

import AVFoundation
import Foundation
import AppKit

class AudioCaptureManager: NSObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingStartTime: Date?
    private let errorManager: ErrorManager
    private var converter: AVAudioConverter?
    
    init(errorManager: ErrorManager) {
        self.errorManager = errorManager
        super.init()
    }
    
    func checkMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    static func clearTempDirectory() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Whispr")
        try? FileManager.default.removeItem(at: tempDir)
    }

    func startRecording() {
        print("🎤 Preparing to record...")
        
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status != .authorized {
            errorManager.handle(error: WhisprError.microphonePermissionDenied, level: .modal)
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            print("❌ Invalid input sample rate")
            errorManager.handle(error: WhisprError.audioCaptureFailed, level: .banner)
            return
        }

        // Target format for conversion: 16kHz, Mono, Float32
        // AVAudioFile will handle the conversion from Float32 to Int16 when writing
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000.0,
            channels: 1,
            interleaved: false
        ) else {
            print("❌ Failed to create target format")
            return
        }
        
        // Settings for the WAV file: 16kHz, Mono, 16-bit PCM
        let recordSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Whispr")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let audioFilePath = tempDir.appendingPathComponent("audio_capture_\(Int(Date().timeIntervalSince1970)).wav")
        
        do {
            audioFile = try AVAudioFile(forWriting: audioFilePath, settings: recordSettings)
            
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, _) in
                guard let self = self, let converter = self.converter, let audioFile = self.audioFile else { return }
                
                var consumed = false
                let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    if consumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    consumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                let ratio = targetFormat.sampleRate / inputFormat.sampleRate
                let targetCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
                
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetCapacity) else {
                    return
                }
                
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputCallback)
                
                if status == .error || error != nil {
                    return
                }
                
                do {
                    try audioFile.write(from: outputBuffer)
                } catch {
                    print("❌ Error writing audio buffer: \(error)")
                }
            }
            
            try engine.start()
            recordingStartTime = Date()
            print("🎤 recording started: \(audioFilePath.lastPathComponent)")
        } catch {
            print("❌ Failed to start recording: \(error)")
            errorManager.handle(error: WhisprError.audioCaptureFailed, level: .banner)
        }
    }
    
    func stopRecording(completion: @escaping (String?) -> Void) {
        guard let engine = audioEngine, let file = audioFile else {
            completion(nil)
            return
        }
        
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        
        let path = file.url.path
        self.audioEngine = nil
        self.audioFile = nil
        
        print("✅ recording stopped: \(path)")
        completion(path)
    }
    
    func cleanup(audioPath: String) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: audioPath))
    }
}
