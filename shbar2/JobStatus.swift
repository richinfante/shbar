//
//  JobStatus.swift
//  shbar2
//
//  Created by Rich Infante on 2/18/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Foundation

enum JobStatus : String {
    /// The job is suspended.
    case Stopped
    
    /// The job is exited.
    case Exited
    
    /// The job is running
    case Running
}
