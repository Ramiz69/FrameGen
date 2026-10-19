//
//  main.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
let mainMenu = MainMenu()
application.delegate = delegate
application.mainMenu = mainMenu.menu

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
