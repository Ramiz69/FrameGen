//
//  DropView.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Cocoa

protocol DropViewProtocol: AnyObject {
    
    func fileSelected(path: String)
    
}

final class DropView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: DropViewProtocol?
    private let defaultDropColor: NSColor = Color.dropLayerColor
    private let defaultColor: NSColor = .clear
    
    // MARK: - Initial methods
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        configureView()
    }
    
    init() {
        super.init(frame: .zero)
        
        configureView()
    }
    
    // MARK: - Life cycle
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if checkFile(sender) {
            animate {
                self.layer?.backgroundColor = self.defaultDropColor.withAlphaComponent(0.3).cgColor
            }
            
            return .copy
        } else {
            return NSDragOperation()
        }
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        animate {
            self.layer?.backgroundColor = self.defaultColor.cgColor
        }
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        animate {
            self.layer?.backgroundColor = self.defaultColor.cgColor
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard
            checkFile(sender),
            let path = makePathFrom(draggingInfo: sender),
            checkIsDirectory(path: path)
        else {
            return false
        }
        
        delegate?.fileSelected(path: path)
        
        return true
    }
    
    // MARK: - Private methods
    
    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = defaultColor.cgColor
        
        registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
    }
    
    private func checkFile(_ drag: NSDraggingInfo) -> Bool {
        guard
            let path = makePathFrom(draggingInfo: drag),
            checkIsDirectory(path: path)
        else {
            return false
        }
        
        var isDirectory: ObjCBool = false
        let fileExist = FileManager().fileExists(atPath: path, isDirectory: &isDirectory)
        if fileExist {
            return isDirectory.boolValue
        }
        
        return false
    }
    
    private func makePathFrom(draggingInfo: NSDraggingInfo) -> String? {
        let pasteboard = draggingInfo.draggingPasteboard
        let board = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? [String]
        let path = board?.first
        
        return path
    }
    
    private func checkIsDirectory(path: String) -> Bool {
        let filePathURL = URL(filePath: path)
        if !filePathURL.pathExtension.isEmpty {
            return false
        }
        
        return true
    }
    
    private func animate(duration: TimeInterval = 0.3,
                         timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut),
                         animations: () -> Void,
                         completionHandler: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            
            context.duration = duration
            context.timingFunction = timingFunction
            animations()
        }, completionHandler: completionHandler)
    }
    
}
