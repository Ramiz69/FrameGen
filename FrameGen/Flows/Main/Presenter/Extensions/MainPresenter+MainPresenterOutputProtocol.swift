//
//  MainPresenter+MainPresenterOutputProtocol.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Foundation

extension MainPresenter: MainPresenterOutputProtocol {
    
    func makeOptions(path: String) {
        view?.openOptions(path: path)
    }
    
    func makeSettings() {
        view?.openSettings()
    }
    
}
