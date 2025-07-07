//
//  KeyManager.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 07/07/2025.
//

import Foundation
import OpenAI

@MainActor
enum KeyManager {
    static func loadAPIKeysIfAvailable() {
        if let token = UserDefaults.standard.string(forKey: "OPENAI_TOKEN"),
           let org = UserDefaults.standard.string(forKey: "OPENAI_ORGANIZATION_ID"),
           !token.isEmpty, !org.isEmpty
        {
            AppState.OPENAI_TOKEN = token
            AppState.OPENAI_ORGANIZATION_ID = org
            print("✅ Loaded OpenAI keys from UserDefaults")
        } else {
            AppState.OPENAI_TOKEN = SecretKeys.OPENAI_TOKEN
            AppState.OPENAI_ORGANIZATION_ID = SecretKeys.OPENAI_ORGANIZATION_ID
            print("✅ Loaded OpenAI keys from SecretKeys")
        }
        
        AppState.openAI = OpenAI(configuration: OpenAI.Configuration(token: AppState.OPENAI_TOKEN, organizationIdentifier: AppState.OPENAI_ORGANIZATION_ID, timeoutInterval: 86400.0))
    }
}
