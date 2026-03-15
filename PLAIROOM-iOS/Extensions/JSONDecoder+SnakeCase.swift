//
//  JSONDecoder+SnakeCase.swift
//  PLAIROOM-iOS
//
//  Created by Claude on 2026/03/14.
//

import Foundation

extension JSONDecoder {
    /// スネークケース↔キャメルケース自動変換を行うデコーダー
    static let snakeCaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
