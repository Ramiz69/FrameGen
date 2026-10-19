//
//  main.swift
//  framegen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import FrameGenCLI
import Foundation

// The tool ships inside FrameGen.app (Contents/Helpers/framegen); all of its logic lives in FrameGenCLI.
exit(await FrameGenTool.run(Array(CommandLine.arguments.dropFirst())))
