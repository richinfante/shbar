//
//  LabelProtocol.swift
//  shbar2
//
//  Created by Rich Infante on 2/19/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Cocoa
import Foundation

/// Provides a generic wrapper around various menu and label types
protocol LabelProtocol {
    var title : String { get set }
    var attributedTitleString: NSAttributedString? { get set }
    var allowsNewlines : Bool { get }
}

extension NSMenuItem : LabelProtocol {
    var allowsNewlines : Bool { return false }
    var attributedTitleString: NSAttributedString? {
        get {
            return self.attributedTitle
        }
        set {
            self.attributedTitle = newValue
        }
    }
}

extension NSStatusBarButton : LabelProtocol {
    var allowsNewlines : Bool { return false }
    var attributedTitleString: NSAttributedString? {
        get {
            return self.attributedTitle
        }
        set {
            if let newValue = newValue {
                self.attributedTitle = newValue
            }
        }
    }
}

