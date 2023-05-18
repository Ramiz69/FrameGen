//
//  Command.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 23.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

final class Command {
    
    // MARK: - Properties
    
    private(set) var scheme: String
    private(set) var configuration: String
    private(set) var scripts: [Script]
    
    // MARK: - Initial methods
    
    required init(scheme: String, configuration: String, scripts: [Script]) {
        self.scheme = scheme
        self.configuration = configuration
        self.scripts = scripts
    }
    
    convenience init() {
        self.init(scheme: "", configuration: "", scripts: [])
    }
    
    // MARK: - Public methods
    
    func setScheme(_ scheme: String) {
        self.scheme = scheme
    }
    
    func setConfiguration(_ configuration: String) {
        self.configuration = configuration
    }
    
    func setScripts(_ scripts: [Script]) {
        self.scripts = scripts
    }
    
}
