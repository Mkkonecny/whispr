//
//  WhisprError.swift
//  Whispr
//

import Foundation

enum WhisprError: LocalizedError {
    case audioCaptureFailed
    case transcriptionFailed
    case textInjectionFailed
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case whisperBinaryNotFound
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .audioCaptureFailed:
            return "Failed to record audio. Please check your microphone."
        case .transcriptionFailed:
            return "Failed to transcribe audio. Please try again."
        case .textInjectionFailed:
            return "Failed to insert text. Check Accessibility permissions."
        case .microphonePermissionDenied:
            return "Microphone permission is required for dictation."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for global hotkeys."
        case .whisperBinaryNotFound:
            return "Whisper engine not found. Please check paths."
        case .modelNotFound:
            return "Whisper model not found."
        }
    }
}
