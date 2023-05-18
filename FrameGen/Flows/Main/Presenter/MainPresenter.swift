//
//  MainPresenter.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Foundation

protocol MainPresenterOutputProtocol: AnyObject {
    func makeOptions(path: String)
    func makeSettings()
}

protocol MainPresenterInputProtocol {
    var view: MainViewInputProtocol? { get }
}

final class MainPresenter: MainPresenterInputProtocol {
    
    var view: MainViewInputProtocol?
    
    required init() {
        
    }
    
}
