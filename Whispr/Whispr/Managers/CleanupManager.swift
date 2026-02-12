//
//  CleanupManager.swift
//  Whispr
//

import AppKit
import Foundation

class CleanupManager {
    private let errorManager: ErrorManager
    private var serverProcess: Process?
    private let port = 8080

    private var projectRoot: String {
        return "/Users/mrkkonecny/whispr"
    }

    private var serverPath: String {
        return "\(projectRoot)/llama.cpp/bin/llama-server"
    }

    private var modelPath: String {
        return "\(projectRoot)/llama.cpp/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
    }

    init(errorManager: ErrorManager) {
        self.errorManager = errorManager

        // Ensure server is killed when app quits
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.stopServer()
        }
    }

    func cleanup(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard PreferencesManager.shared.isPolishModeEnabled else {
            completion(.success(text))
            return
        }

        ensureServerRunning { [weak self] success in
            guard let self = self, success else {
                completion(.failure(WhisprError.transcriptionFailed))
                return
            }

            self.sendCompletionRequest(text: text, completion: completion)
        }
    }

    private func ensureServerRunning(completion: @escaping (Bool) -> Void) {
        // Simple check if server is responsive
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                // Not running, start it
                self?.startServer(completion: completion)
            }
        }.resume()
    }

    private func startServer(completion: @escaping (Bool) -> Void) {
        stopServer()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: serverPath)
        process.arguments = [
            "-m", modelPath,
            "--port", "\(port)",
            "-t", "4",  // Use fewer threads to avoid freezing
            "--n-gpu-layers", "99",
            "--threads-batch", "4",
            "--ctx-size", "2048",
            "--parallel", "1",
        ]

        // Redirect output to avoid cluttering or blocking
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        let libPath = "\(projectRoot)/llama.cpp/bin"
        process.environment = ["DYLD_LIBRARY_PATH": libPath]

        do {
            try process.run()
            self.serverProcess = process

            // Wait for server to become ready
            var attempts = 0
            func checkReady() {
                let url = URL(string: "http://127.0.0.1:\(port)/health")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 0.5

                URLSession.shared.dataTask(with: request) { _, response, _ in
                    if let httpResponse = response as? HTTPURLResponse,
                        httpResponse.statusCode == 200
                    {
                        print("✅ AI Cleanup Server is ready")
                        completion(true)
                    } else if attempts < 20 {
                        attempts += 1
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                            checkReady()
                        }
                    } else {
                        print("❌ AI Cleanup Server failed to start")
                        completion(false)
                    }
                }.resume()
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                checkReady()
            }
        } catch {
            print("❌ Failed to launch llama-server: \(error)")
            completion(false)
        }
    }

    private func sendCompletionRequest(
        text: String, completion: @escaping (Result<String, Error>) -> Void
    ) {
        let url = URL(string: "http://127.0.0.1:\(port)/completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>

            You are a transcription cleanup tool.
            1. Remove filler words (um, uh, like, you know, basically).
            2. Preserve casual tone. DO NOT fix "alright" to "all right".
            3. Ensure punctuation is correct, especially for questions.
            4. Output ONLY the cleaned text with NO explanation.<|eot_id|><|start_header_id|>user<|end_header_id|>

            Clean this text: "\(text)"<|eot_id|><|start_header_id|>assistant<|end_header_id|>
            """

        let body: [String: Any] = [
            "prompt": prompt,
            "n_predict": 512,
            "temperature": 0.1,
            "stop": ["<|eot_id|>", "<|start_header_id|>", "<|end_header_id|>"],
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let content = json["content"] as? String
            else {
                completion(.failure(WhisprError.transcriptionFailed))
                return
            }

            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✨ AI Polish Result: \(cleaned)")
            completion(.success(cleaned))
        }.resume()
    }

    func stopServer() {
        if let process = serverProcess, process.isRunning {
            process.terminate()
        }
        serverProcess = nil
    }
}
