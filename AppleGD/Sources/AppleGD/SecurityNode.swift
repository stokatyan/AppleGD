//
//  SecurityNode.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 8/6/25.
//

import SwiftGodot
import Security

@Godot
class SecurityNode: Node {
    
    /**
     Fetches the leaderboards for the given ids, and then load's the player's entry for each leaderboard.
     The `didLoadPlayerEntry` is emitted for each entry that is loaded for the player.
     */
    @Callable(autoSnakeCase: true)
    func saveKey(value: String, tag: String) -> Bool {
        let tagData = tag.data(using: .utf8)!
        let addquery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecValueRef as String: value
        ]
        
        let status = SecItemAdd(addquery as CFDictionary, nil)
        guard status == errSecSuccess else {
            return false
        }
        return true
    }
    
    @Callable(autoSnakeCase: true)
    func getKey(tag: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let key = item else {
            return ""
        }
        
        return (key as? String) ?? ""
    }
    
}
