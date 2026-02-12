//
//  PreferencesManager.swift
//  Whispr
//

import Combine
import Foundation

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    enum Keys {
        static let isPolishModeEnabled = "isPolishModeEnabled"
    }

    @Published var isPolishModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPolishModeEnabled, forKey: Keys.isPolishModeEnabled)
        }
    }

    private init() {
        self.isPolishModeEnabled = UserDefaults.standard.bool(forKey: Keys.isPolishModeEnabled)
    }
}
