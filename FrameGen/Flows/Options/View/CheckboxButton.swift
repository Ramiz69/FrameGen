//
//  CheckboxButton.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

final class CheckboxButton: NSButton {
    
    // MARK: - Properties
    
    enum CheckboxType: Int {
        case iPhoneOS = 0
        case simulator = 1
        case macCatalyst = 2
        
        var title: String {
            switch self {
            case .iPhoneOS:
                return "iOS"
            case .simulator:
                return "Simulator"
            case .macCatalyst:
                return "Mac catalyst"
            }
        }
        
        var scriptType: Script {
            switch self {
            case .iPhoneOS:
                return .iPhoneOS
            case .simulator:
                return .simulatorOS
            case .macCatalyst:
                return .macCatalyst
            }
        }
    }
    let type: CheckboxType
    
    // MARK: - Initial methods
    
    required init(type: CheckboxType, target: Any?, action: Selector?) {
        self.type = type
        super.init(frame: .zero)
        
        setButtonType(.switch)
        title = type.title
        self.target = target as AnyObject?
        self.action = action
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
