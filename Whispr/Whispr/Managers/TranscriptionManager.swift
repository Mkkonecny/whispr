//
//  TranscriptionManager.swift
//  Whispr
//

import Foundation

class TranscriptionManager {
    private let errorManager: ErrorManager

    private var projectRoot: String {
        return "/Users/mrkkonecny/whispr"
    }

    private var whisperBinaryPath: String {
        return "\(projectRoot)/whisper.cpp/build/bin/whisper-cli"
    }

    private var modelPath: String {
        return "\(projectRoot)/whisper.cpp/models/ggml-base.bin"
    }

    init(errorManager: ErrorManager) {
        self.errorManager = errorManager
    }

    func transcribe(audioPath: String, completion: @escaping (Result<Transcription, Error>) -> Void)
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperBinaryPath)

        // We removed -nt (no-timestamps) to ensure the parser finds the text correctly
        process.arguments = [
            "-m", modelPath,
            "-f", audioPath,
            "-t", "8",
            "-l", "auto",
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        // Also capture stderr to help debug errors
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: outputData, encoding: .utf8) else {
                    print("❌ Could not decode output data")
                    completion(.failure(WhisprError.transcriptionFailed))
                    return
                }

                let text = self.parseWhisperOutput(output)
                if text.isEmpty {
                    // Log the raw output if parsing failed
                    print("⚠️ Parser yielded empty text. Raw output length: \(output.count)")
                    completion(.failure(WhisprError.transcriptionFailed))
                } else {
                    completion(
                        .success(Transcription(text: text, language: "auto", processingTime: 0)))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    private func parseWhisperOutput(_ output: String) -> String {
        let lines = output.split(separator: "\n")
        var transcriptionLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            var text = ""
            if let range = trimmed.range(of: "]") {
                text = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                // Handle output WITHOUT timestamps
                if !trimmed.hasPrefix("whisper_") && !trimmed.hasPrefix("main:")
                    && !trimmed.hasPrefix("ggml_") && !trimmed.hasPrefix("system_info:")
                {
                    text = trimmed
                }
            }

            if !text.isEmpty {
                // Filter out common Whisper hallucinations/noise markers
                let noiseMarkers = ["[silence]", "[inaudible]", "[music]", "[laughter]", "[noise]"]
                var filteredText = text
                for marker in noiseMarkers {
                    filteredText = filteredText.replacingOccurrences(
                        of: marker, with: "", options: [.caseInsensitive])
                }

                let finalized = filteredText.trimmingCharacters(in: .whitespaces)
                if !finalized.isEmpty {
                    transcriptionLines.append(finalized)
                }
            }
        }

        return transcriptionLines.joined(separator: " ")
    }

    func cleanup(audioPath: String) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: audioPath))
    }
}

struct Transcription {
    let text: String
    let language: String
    let processingTime: TimeInterval
}
