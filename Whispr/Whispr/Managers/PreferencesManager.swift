//
//  PreferencesManager.swift
//  Whispr
//

import Combine
import Foundation
import SwiftUI

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    enum Keys {
        static let isPolishModeEnabled = "isPolishModeEnabled"
        static let selectedModel = "selectedModel"
    }

    @Published var isPolishModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPolishModeEnabled, forKey: Keys.isPolishModeEnabled)
        }
    }

    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: Keys.selectedModel)
        }
    }

    private init() {
        self.isPolishModeEnabled = UserDefaults.standard.bool(forKey: Keys.isPolishModeEnabled)
        self.selectedModel = UserDefaults.standard.string(forKey: Keys.selectedModel) ?? "base"
    }
}
