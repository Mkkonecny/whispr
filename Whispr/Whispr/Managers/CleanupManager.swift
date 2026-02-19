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

        ServerManager.shared.ensureServerRunning(type: .llama) { [weak self] success in
            guard let self = self, success else {
                completion(.failure(WhisprError.transcriptionFailed))
                return
            }

            self.sendPolishRequest(text: text, completion: completion)
        }
    }

    // Removed local server management methods as they are now in ServerManager

    func processAgentRequest(
        command: String, context: String?, completion: @escaping (Result<String, Error>) -> Void
    ) {
        ServerManager.shared.ensureServerRunning(type: .llama) { [weak self] success in
            guard let self = self, success else {
                completion(.failure(WhisprError.transcriptionFailed))
                return
            }

            self.sendAgentRequest(command: command, context: context, completion: completion)
        }
    }

    private func sendAgentRequest(
        command: String, context: String?, completion: @escaping (Result<String, Error>) -> Void
    ) {
        let port = ServerManager.shared.getPort(for: .llama)
        let url = URL(string: "http://127.0.0.1:\(port)/completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
            You are a silent text editor. You receive a command and optionally some selected text.
            Rules:
            - Output ONLY the final edited text. Nothing else.
            - Do NOT write any introduction, label, explanation, or commentary.
            - Do NOT start your response with words like "Here", "Sure", "Polished", "Result", "Output", "Modified", "Edited", "Here's", "The text", "Below" or similar.
            - Do NOT use markdown formatting or code blocks.
            - Do NOT repeat the command back.
            - Preserve original line breaks unless the command says otherwise.
            - Your ENTIRE response is the replaced text, starting immediately with the first character of the result.
            """

        let userPrompt: String
        if let context = context, !context.isEmpty {
            userPrompt = """
                Command: \(command)

                Selected Text:
                \(context)
                """
        } else {
            userPrompt = command
        }

        let prompt = """
            <|start_header_id|>system<|end_header_id|>

            \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>

            \(userPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>
            """

        // Reuse the sending logic
        sendLLMRequest(prompt: prompt, completion: completion)
    }

    private func sendLLMRequest(
        prompt: String, completion: @escaping (Result<String, Error>) -> Void
    ) {
        let port = ServerManager.shared.getPort(for: .llama)
        let url = URL(string: "http://127.0.0.1:\(port)/completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "n_predict": 1024,
            "temperature": 0.3,  // Lower temp for more deterministic editing
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

            var result = content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip leading quotes that some models wrap around their output
            if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count > 2 {
                result = String(result.dropFirst().dropLast())
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Post-processing: strip chatty label prefixes that the model sometimes outputs
            // despite instructions. Covers both "Label: text" and "Label:\ntext" patterns.
            result = self.stripChattPrefix(from: result)

            print("[CleanupManager] INFO: Agent processing result: \(result)")
            completion(.success(result))
        }.resume()
    }

    /// Strips common chatty label prefixes that small models emit before the actual content.
    /// Handles patterns: "Label: text", "Label:\ntext", "Label:\n\ntext"
    private func stripChattPrefix(from text: String) -> String {
        // All known chatty openers — matched case-insensitively at the start of the string
        let chattPrefixes = [
            // Generic openers
            "here is the ", "here's the ", "here is your ", "here's your ",
            "sure, here", "sure! here", "sure.",
            "of course", "absolutely",
            "below is", "below you",
            // Label-style prefixes (will strip up to and including the first colon)
            "polished:", "polished version:", "polished text:",
            "result:", "output:", "response:",
            "modified text:", "edited text:", "updated text:", "cleaned text:",
            "the text:", "the result:", "the output:",
            "selected text:", "transcription:",
            "cleaned:", "clean:",
        ]

        var result = text
        let lower = result.lowercased()

        for prefix in chattPrefixes {
            if lower.hasPrefix(prefix) {
                // If the prefix ends with ':', the content follows after the colon
                if prefix.hasSuffix(":") || lower.hasPrefix(prefix) {
                    // Find first colon to strip the whole label
                    if let colonRange = result.range(of: ":") {
                        let afterColon = String(result[colonRange.upperBound...])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !afterColon.isEmpty {
                            result = afterColon
                            break
                        }
                    }
                    // No colon found — strip up to the first newline
                    if let newlineRange = result.range(of: "\n") {
                        let afterNewline = String(result[newlineRange.upperBound...])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !afterNewline.isEmpty {
                            result = afterNewline
                            break
                        }
                    }
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendPolishRequest(
        text: String, completion: @escaping (Result<String, Error>) -> Void
    ) {
        let systemPrompt = """
            You are a silent transcription cleaner.
            Rules:
            - Output ONLY the cleaned text. Nothing else.
            - Do NOT write any label, prefix, explanation, or commentary before or after the text.
            - Do NOT start with words like "Here", "Sure", "Cleaned", "Polished", "Result" or similar.
            - Remove filler words (um, uh, like, you know, basically, so, right).
            - Fix punctuation, especially missing question marks.
            - Preserve casual tone. Do NOT replace "alright" with "all right".
            - Your ENTIRE response is the cleaned text, starting immediately with the first word.
            """
        let userPrompt = "Clean this transcription: \"\(text)\""

        let prompt = """
            <|start_header_id|>system<|end_header_id|>

            \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>

            \(userPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>
            """

        sendLLMRequest(prompt: prompt, completion: completion)
    }

    func stopServer() {
        if let process = serverProcess, process.isRunning {
            process.terminate()
        }
        serverProcess = nil
    }
}
