//
//  JSONEncoder+SnakeCase.swift
//  PLAIROOM-iOS
//
//  Created by Claude on 2026/03/14.
//

import Foundation

extension JSONEncoder {
    /// キャメルケース↔スネークケース自動変換を行うエンコーダー
    static let snakeCaseEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
