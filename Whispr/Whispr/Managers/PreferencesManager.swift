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
        static let glassStyle = "glassStyle"
        static let iconStyle = "iconStyle"
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
    
    @Published var glassStyle: String {
        didSet { UserDefaults.standard.set(glassStyle, forKey: Keys.glassStyle) }
    }

    @Published var iconStyle: String {
        didSet { UserDefaults.standard.set(iconStyle, forKey: Keys.iconStyle) }
    }

    private init() {
        self.isPolishModeEnabled = UserDefaults.standard.bool(forKey: Keys.isPolishModeEnabled)
        self.selectedModel = UserDefaults.standard.string(forKey: Keys.selectedModel) ?? "base"
        self.glassStyle = UserDefaults.standard.string(forKey: Keys.glassStyle) ?? "clear"
        self.iconStyle = UserDefaults.standard.string(forKey: Keys.iconStyle) ?? "clear"
    }
}
