//
//  main.swift
//  framegen-dev
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import FrameGenCLI
import Foundation

exit(await FrameGenTool.run(Array(CommandLine.arguments.dropFirst())))
