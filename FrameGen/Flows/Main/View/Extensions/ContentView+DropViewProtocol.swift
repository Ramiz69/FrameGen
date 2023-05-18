//
//  ContentView+DropViewProtocol.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

extension ContentView: DropViewProtocol {
    
    func fileSelected(path: String) {
        delegate?.fileSelected(path)
    }
    
}
