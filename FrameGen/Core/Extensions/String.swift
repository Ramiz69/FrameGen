//
//  String.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

extension String {
    
    func splitAtFirst(delimiter: String) -> (after: String, before: String)? {
        guard
            let upperIndex = (range(of: delimiter)?.upperBound),
            let lowerIndex = (range(of: delimiter)?.lowerBound)
        else {
            return nil
        }
        
        let firstPart = String(prefix(upTo: lowerIndex))
        let lastPart = String(suffix(from: upperIndex))
        
        return (firstPart, lastPart)
    }
    
}
