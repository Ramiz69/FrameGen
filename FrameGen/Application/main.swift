//
//  main.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Cocoa

let application = NSApplication.shared
let delegate = AppDelegate()
let mainMenu = MainMenu()
application.delegate = delegate
application.mainMenu = mainMenu

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
