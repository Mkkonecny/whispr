import AppKit
import Foundation

enum ServerType {
    case whisper
    case llama
    case sherpa
}

class ServerManager {
    static let shared = ServerManager()

    private var processes: [ServerType: Process] = [:]
    private var ports: [ServerType: Int] = [
        .whisper: 8081,
        .llama: 8082,
        .sherpa: 8083,
    ]

    private let projectRoot = "/Users/mrkkonecny/whispr"

    private init() {
        // Ensure servers are killed when app quits
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.stopAllServers()
        }
    }

    func getPort(for type: ServerType) -> Int {
        return ports[type] ?? 8080
    }

    func ensureServerRunning(type: ServerType, completion: @escaping (Bool) -> Void) {
        if isServerRunning(type: type) {
            completion(true)
            return
        }

        startServer(type: type, completion: completion)
    }

    private func isServerRunning(type: ServerType) -> Bool {
        // Simple check if process is running
        guard let process = processes[type], process.isRunning else {
            return false
        }
        return true
    }

    private func startServer(type: ServerType, completion: @escaping (Bool) -> Void) {
        stopServer(type: type)  // Ensure clean state

        let process = Process()
        let port = getPort(for: type)

        switch type {
        case .whisper:
            let binaryPath = "\(projectRoot)/whisper.cpp/build/bin/whisper-server"
            let modelPath = "\(projectRoot)/whisper.cpp/models/ggml-base.bin"  // Default, should likely be configurable

            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = [
                "-m", modelPath,
                "--port", "\(port)",
                "--host", "127.0.0.1",
            ]

        case .llama:
            let binaryPath = "\(projectRoot)/llama.cpp/bin/llama-server"
            let modelPath = "\(projectRoot)/llama.cpp/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf"

            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = [
                "-m", modelPath,
                "--port", "\(port)",
                "--host", "127.0.0.1",
                "-t", "4",
                "--n-gpu-layers", "99",
                "--ctx-size", "2048",
                "--parallel", "1",
            ]

            // Set library path for llama
            let libPath = "\(projectRoot)/llama.cpp/bin"
            process.environment = ["DYLD_LIBRARY_PATH": libPath]

        case .sherpa:
            let binaryPath = "\(projectRoot)/sherpa-onnx/bin/sherpa-onnx-online-websocket-server"
            let modelDir = "\(projectRoot)/sherpa-onnx/models/zipformer"

            // Verify model files exist
            let encoder = "\(modelDir)/encoder-epoch-99-avg-1.onnx"
            let decoder = "\(modelDir)/decoder-epoch-99-avg-1.onnx"
            let joiner = "\(modelDir)/joiner-epoch-99-avg-1.onnx"
            let tokens = "\(modelDir)/tokens.txt"

            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = [
                "--port=\(port)",
                "--encoder=\(encoder)",
                "--decoder=\(decoder)",
                "--joiner=\(joiner)",
                "--tokens=\(tokens)",
                "--sample-rate=16000",
            ]
        }

        // Output handling to prevent buffer filling and hanging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                print(
                    "[ServerManager:\(type)] INFO: \(str.trimmingCharacters(in: .whitespacesAndNewlines))"
                )
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                // whisper-server and llama-server write all output (including normal info) to stderr
                print(
                    "[ServerManager:\(type)] STDERR: \(str.trimmingCharacters(in: .whitespacesAndNewlines))"
                )
            }
        }

        process.terminationHandler = { _ in
            print("[ServerManager:\(type)] INFO: Server process terminated.")
            // Clean up readability handlers
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
        }

        do {
            try process.run()
            processes[type] = process

            // Wait for server to be ready with health check
            waitForServerReady(port: port, completion: completion)
        } catch {
            print("[ServerManager:\(type)] ERROR: Failed to start server: \(error)")
            completion(false)
        }
    }

    private func waitForServerReady(port: Int, completion: @escaping (Bool) -> Void) {
        var attempts = 0
        let maxAttempts = 20

        func check() {
            let url = URL(string: "http://127.0.0.1:\(port)/health")!  // Most servers implement /health
            var request = URLRequest(url: url)
            request.timeoutInterval = 0.5

            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    attempts += 1
                    if attempts < maxAttempts {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { check() }
                    } else {
                        completion(false)
                    }
                }
            }.resume()
        }

        // Initial delay to let process start
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { check() }
    }

    func stopServer(type: ServerType) {
        if let process = processes[type], process.isRunning {
            process.terminate()
        }
        processes[type] = nil
    }

    func stopAllServers() {
        for type in processes.keys {
            stopServer(type: type)
        }
    }
}
