//
//  Script.swift
//  shbar2
//
//  Created by Rich Infante on 2/18/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Foundation

/// Wrapper for process
class Script : Codable {
    /// Absolute path to binary
    var bin: String
    
    /// Arguments to binary
    var args: [String]
    
    /// Environment variables
    var env: [String:String]

    // Pipe output from the process
    var uuid: UUID?
    var process: Process?

    private enum CodingKeys: String, CodingKey {
        case bin
        case args
        case env
    }
    
    /// Intialize a new script
    init (bin: String, args:[String], env: [String:String]) {
        self.bin = bin
        self.args = args
        self.env = env
    }
    
    /// Launch a job.
    func launchJob(launched: ((Process)->())? = nil, completed: ((Int32)->())? = nil) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }
            
            // Create a process instance
            let task = Process()
            self.process = task
            
            // Assign a uuid to this script if it is not set yet
            if self.uuid == nil {
                let uuid = UUID()
                self.uuid = uuid
            }
            
            // Set logfile path
            let logfile = "\(AppDelegate.userHomeDirectoryPath)/Library/Logs/shbar/\(self.uuid!.uuidString).log"
            
            // Set process options
            task.currentDirectoryPath = "/"
            task.environment = self.env
            task.launchPath = self.bin
            task.arguments = self.args
            
            // Try to attach the logfile to the process STDOUT/STDERR
            do {
                print("Create log for \(self.bin) launch: \(logfile)")
                FileManager.default.createFile(atPath: logfile, contents: nil)
                let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: logfile))
                task.standardOutput = handle
                task.standardError = handle
            } catch let error {
                print("Error creating logfile: \(error)")
            }
            
            // Launch the task
            task.launch()
            
            // Notify of laynch
            DispatchQueue.main.sync {
                launched?(task)
            }
            
            print("wait for exit: \(self.bin)")
            
            // Grab the file handle so we can log when it dies.
            let handle: FileHandle? = task.standardOutput as? FileHandle
            task.waitUntilExit()
            
            // Write status to handle if it exists.
            if let handle = handle, let data = "exited: \(task.terminationStatus)".data(using: .utf8) {
                handle.write(data)
            }

            // Log status and notify callback
            print("Child process exited with code \(task.terminationStatus)")
            DispatchQueue.main.sync {
                completed?(task.terminationStatus)
            }
        }
    }
    
    
    /// Execute script in background, collecting output
    func execute(launched: ((Process)->())? = nil, completed: ((Int32, String)->())? = nil) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }
            
            let pipe = Pipe()
            let task = Process()
            self.process = task
            if self.uuid == nil {
                let uuid = UUID()
                self.uuid = uuid
            }
            
            let errLogPath = "\(AppDelegate.userHomeDirectoryPath)/Library/Logs/shbar/\(self.uuid!.uuidString).log"
            
            task.currentDirectoryPath = "/"
            task.environment = self.env
            task.launchPath = self.bin
            task.arguments = self.args
            print(self.bin, self.env, self.args)
            task.standardOutput = pipe
            do {
                FileManager.default.createFile(atPath: errLogPath, contents: nil)
                print("Create log for \(self.bin) launch: \(errLogPath)")
                let handle2 = try FileHandle(forWritingTo: URL(fileURLWithPath: errLogPath))
                task.standardError = handle2
            } catch let error {
                print("Error creating config directory: \(error)")
            }
            task.launch()
            DispatchQueue.main.sync {
                launched?(task)
            }
            task.waitUntilExit()
            let status = task.terminationStatus
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String
            print("Child process exited with code \(status)")
            DispatchQueue.main.sync {
                completed?(status, output)
            }
        }
    }
}
