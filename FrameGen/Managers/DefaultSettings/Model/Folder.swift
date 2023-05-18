//
//  Folder.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 07.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

final class Folder {
    
    // MARK: - Properties
    
    enum FolderType {
        case `default`(String)
        case custom(String)
    }
    
    let path: String
    let pathForProcess: String
    
    // MARK: - Initial methods
    
    init(type: FolderType) {
        switch type {
        case .default(let path):
            self.path = path
            pathForProcess = "./\(path)/"
        case .custom(let path):
            self.path = path
            pathForProcess = path
        }
    }
    
}
