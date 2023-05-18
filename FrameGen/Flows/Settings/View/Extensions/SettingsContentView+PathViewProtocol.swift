//
//  SettingsContentView+PathViewProtocol.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 12.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

extension SettingsContentView: PathViewProtocol {
    
    func didTapChooseFolder() {
        Task {
            let response = await openPanel.begin()
            switch response {
            case .OK:
                guard let url = openPanel.url else { return }
                
                delegate?.fileSelected(url.path())
                pathView.updateState(.custom)
            default: break
            }
        }
    }
    
}
