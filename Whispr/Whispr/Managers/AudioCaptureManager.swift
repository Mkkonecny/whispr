//
//  AudioCaptureManager.swift
//  Whispr
//

import AVFoundation
import AppKit
import Combine
import Foundation
import SwiftUI

class AudioCaptureManager: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingStartTime: Date?
    private let errorManager: ErrorManager
    private var converter: AVAudioConverter?

    @Published var audioLevel: Float = 0.0
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
        print("[AudioCaptureManager] INFO: Preparing to start recording session...")

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
            print(
                "[AudioCaptureManager] ERROR: Invalid input sample rate detected from audio device."
            )
            errorManager.handle(error: WhisprError.audioCaptureFailed, level: .banner)
            return
        }

        // Target format for conversion: 16kHz, Mono, Float32
        // AVAudioFile will handle the conversion from Float32 to Int16 when writing
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000.0,
                channels: 1,
                interleaved: false
            )
        else {
            print(
                "[AudioCaptureManager] ERROR: Failed to create target audio format for conversion.")
            return
        }

        // Settings for the WAV file: 16kHz, Mono, 16-bit PCM
        let recordSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Whispr")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let audioFilePath = tempDir.appendingPathComponent(
            "audio_capture_\(Int(Date().timeIntervalSince1970)).wav")

        do {
            audioFile = try AVAudioFile(forWriting: audioFilePath, settings: recordSettings)

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
                [weak self] (buffer, _) in
                guard let self = self, let converter = self.converter,
                    let audioFile = self.audioFile
                else { return }

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

                guard
                    let outputBuffer = AVAudioPCMBuffer(
                        pcmFormat: targetFormat, frameCapacity: targetCapacity)
                else {
                    return
                }

                var error: NSError?
                let status = converter.convert(
                    to: outputBuffer, error: &error, withInputFrom: inputCallback)

                if status == .error || error != nil {
                    return
                }

                // Calculate RMS level for visualization
                if let channelData = outputBuffer.floatChannelData?[0] {
                    let frameLength = UInt32(outputBuffer.frameLength)
                    var sum: Float = 0
                    for i in 0..<Int(frameLength) {
                        sum += channelData[i] * channelData[i]
                    }
                    let rms = sqrt(sum / Float(frameLength))

                    DispatchQueue.main.async {
                        self.audioLevel = rms
                    }
                }

                do {
                    try audioFile.write(from: outputBuffer)
                } catch {
                    print(
                        "[AudioCaptureManager] ERROR: Failed to write audio buffer to file: \(error)"
                    )
                }
            }

            try engine.start()
            recordingStartTime = Date()
            print(
                "[AudioCaptureManager] INFO: Recording started successfully. File: \(audioFilePath.lastPathComponent)"
            )
        } catch {
            print("[AudioCaptureManager] ERROR: Failed to start audio engine: \(error)")
            errorManager.handle(error: WhisprError.audioCaptureFailed, level: .banner)
        }
    }

    var isRecording: Bool {
        return audioEngine != nil
    }

    func stopRecording(completion: @escaping (String?) -> Void) {
        guard let engine = audioEngine, let file = audioFile else {
            completion(nil)
            return
        }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)

        // Capture the URL before nil-ing
        let url = file.url
        let path = url.path

        // Release references to close the file
        self.audioEngine = nil
        self.audioFile = nil

        // Wait a moment to ensure file handle is released and data is flushed to disk
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Verify file exists and has content
            do {
                let checkAttr = try FileManager.default.attributesOfItem(atPath: path)
                if let size = checkAttr[.size] as? UInt64 {
                    print(
                        "[AudioCaptureManager] INFO: Recording stopped. File: \(path) (Size: \(size) bytes)"
                    )
                    if size < 100 {
                        print(
                            "[AudioCaptureManager] WARN: Audio file size is suspiciously small (< 100 bytes)."
                        )
                    }
                }
            } catch {
                print(
                    "[AudioCaptureManager] WARN: Failed to retrieve attributes for audio file: \(error)"
                )
            }

            completion(path)
        }
    }

    func cleanup(audioPath: String) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: audioPath))
    }
}
