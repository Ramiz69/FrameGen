//
//  TaskError.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Foundation

enum TaskError: Error {
    case taskFailure(code: Int, message: String)
    case parsingError(data: Data)
}

extension TaskError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case let .taskFailure(code, message):
            return "Code = \(code). Message = \(message)"
        case let .parsingError(data):
            let output = String(data: data, encoding: .utf8)
            
            return output
        }
    }
}
