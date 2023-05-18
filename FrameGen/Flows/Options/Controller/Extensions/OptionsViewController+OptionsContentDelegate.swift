//
//  OptionsViewController+OptionsContentDelegate.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

extension OptionsViewController: OptionsContentDelegate {
    
    func dismissView() {
        presenter.cancelAllScripts()
        dismiss(self)
    }
    
    func runScripts(_ scripts: [Script]) {
        presenter.runScripts(scripts)
    }
    
    func didSelectIndex(box: OptionsContentView.ComboboxType, at index: Int) {
        switch box {
        case .scheme:
            let scheme = data.schemes[index]
            presenter.setScheme(scheme)
        case .configuration:
            let configuration = data.configurations[index]
            presenter.setConfiguration(configuration)
        }
    }
    
}
