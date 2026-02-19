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
        let model = PreferencesManager.shared.selectedModel
        return "\(projectRoot)/whisper.cpp/models/ggml-\(model).bin"
    }

    init(errorManager: ErrorManager) {
        self.errorManager = errorManager
    }

    func transcribe(audioPath: String, completion: @escaping (Result<Transcription, Error>) -> Void)
    {
        ServerManager.shared.ensureServerRunning(type: .whisper) { [weak self] success in
            guard let self = self, success else {
                print("[TranscriptionManager] ERROR: Server failed to start or is not running.")
                completion(.failure(WhisprError.transcriptionFailed))
                return
            }

            self.sendTranscriptionRequest(audioPath: audioPath, completion: completion)
        }
    }

    private func sendTranscriptionRequest(
        audioPath: String, completion: @escaping (Result<Transcription, Error>) -> Void
    ) {
        let port = ServerManager.shared.getPort(for: .whisper)
        let url = URL(string: "http://127.0.0.1:\(port)/inference")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileUrl = URL(fileURLWithPath: audioPath)

        // Verify file integrity before sending
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: audioPath)
            if let size = attr[.size] as? UInt64, size < 100 {
                print(
                    "[TranscriptionManager] WARN: Audio file is too small (\(size) bytes). Aborting."
                )
                completion(.failure(WhisprError.transcriptionFailed))
                return
            }
        } catch {
            print("[TranscriptionManager] ERROR: Failed to check file attributes: \(error)")
            completion(.failure(WhisprError.transcriptionFailed))
            return
        }

        guard let fileData = try? Data(contentsOf: fileUrl) else {
            print("[TranscriptionManager] ERROR: Failed to read audio file at \(audioPath)")
            completion(.failure(WhisprError.transcriptionFailed))
            return
        }

        var body = Data()

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Add response_format=json
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[TranscriptionManager] ERROR: Network error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("[TranscriptionManager] ERROR: No response data received.")
                completion(.failure(WhisprError.transcriptionFailed))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print(
                    "[TranscriptionManager] ERROR: Server returned status \(httpResponse.statusCode)"
                )
                if let str = String(data: data, encoding: .utf8) {
                    print("[TranscriptionManager] DEBUG: Response body: \(str)")
                }
            }

            // Parse JSON response
            // Expected format: { "text": "..." }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let text = json["text"] as? String
                {
                    let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(
                        .success(
                            Transcription(text: cleanText, language: "auto", processingTime: 0)))
                } else {
                    print(
                        "[TranscriptionManager] ERROR: JSON missing 'text' field or invalid structure."
                    )
                    completion(.failure(WhisprError.transcriptionFailed))
                }
            } catch {
                print("[TranscriptionManager] ERROR: JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
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
