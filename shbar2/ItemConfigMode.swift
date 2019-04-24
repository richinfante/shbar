//
//  ItemConfigMode.swift
//  shbar2
//
//  Created by Rich Infante on 2/18/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Foundation

enum ItemConfigMode : String, Codable {
    /// Refreshes contents with output of script.
    case RefreshingItem

    /// Displays job name / status icon.
    /// Contains submenu of launch actions.
    case JobStatus

    /// Quit the app.
    case ApplicationQuit
}
