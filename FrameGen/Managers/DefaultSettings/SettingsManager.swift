//
//  SettingsManager.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 07.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

protocol SettingsManagerProtocol: AnyObject {
    func getDefaultFolder() -> Folder
    func getFolder() -> Folder
    func setNewPath(_ path: String)
}

final class SettingsManager: SettingsManagerProtocol {
    
    // MARK: - Properties
    
    static let shared = SettingsManager()
    private var currentFolder: Folder?
    private let defaultFolder = Folder(type: .default("build"))
    
    // MARK: - Initial methods
    
    private init() {
        
    }
    
    // MARK: - Public methods
    
    func getDefaultFolder() -> Folder {
        return defaultFolder
    }
    
    func getFolder() -> Folder {
        return currentFolder ?? defaultFolder
    }
    
    func setNewPath(_ path: String) {
        currentFolder = Folder(type: .custom(path))
    }
    
}
