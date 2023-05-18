//
//  URL+FindDirectory.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 18.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

extension URL {
    
    var xcodeProjectDirectory: URL? {
        if path() == "/" {
            return nil
        }
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(at: self,
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else {
            return nil
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "xcodeproj" {
            return fileURL.deletingLastPathComponent()
        }

        return nil
    }
    
}
