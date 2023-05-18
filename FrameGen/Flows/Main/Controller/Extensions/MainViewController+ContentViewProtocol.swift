//
//  MainViewController+ContentViewProtocol.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Cocoa

extension MainViewController: ContentViewProtocol {
    
    func fileSelected(_ path: String) {
        presenter.makeOptions(path: path)
    }
    
    func didTapSettings() {
        presenter.makeSettings()
    }
    
}
