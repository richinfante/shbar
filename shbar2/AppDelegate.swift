//
//  AppDelegate.swift
//  shbar2
//
//  Created by Rich Infante on 2/14/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Cocoa
import Foundation

/// Wrapper for process
class Script : Codable {
    /// Absolute path to binary
    var bin: String
    
    /// Arguments to binary
    var args: [String]
    
    /// Environment variables
    var env: [String:String]
    
    /// Intialize a new script
    init (bin: String, args:[String], env: [String:String]) {
        self.bin = bin
        self.args = args
        self.env = env
    }
    
    /// Execute script in background, collecting output
    func execute(launched: ((Process)->())? = nil, completed: ((Int32, String)->())?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }

            let pipe = Pipe()
            let task = Process()
            task.currentDirectoryPath = "/"
            task.environment = self.env
            task.launchPath = self.bin
            task.arguments = self.args
            task.standardOutput = pipe
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

enum ItemConfigMode : String, Codable {
    case RefreshingItem
    case JobStatus
    case ApplicationQuit
}

enum JobStatus : String {
    case Stopped
    case Exited
    case Running
}

class ItemConfig : Codable {
    var mode: ItemConfigMode? = .RefreshingItem
    var title: String?
    var titleScript: Script?
    var titleRefreshInterval: TimeInterval?
    var actionScript: Script?
    var shortcutKey: String?
    var jobScript: Script?
    var reloadJob: Bool?
    var autostartJob: Bool?
    var menuItem: NSMenuItem?
    var refreshTimer: Timer?
    var jobStatusItem: NSMenuItem?
    var jobExitStatus: Int32?
    var currentJob: Process?
    
    private enum CodingKeys: String, CodingKey {
        case mode
        case title
        case titleScript
        case titleRefreshInterval
        case actionScript
        case shortcutKey
        case jobScript
        case reloadJob
        case autostartJob
    }
    
    init(
        mode: ItemConfigMode? = .RefreshingItem,
        title: String? = nil,
        titleScript: Script? = nil,
        titleRefreshInterval: TimeInterval? = nil,
        actionScript: Script? = nil,
        jobScript: Script? = nil,
        reloadJob: Bool? = false,
        autostartJob: Bool? = false,
        shortcutKey: String? = nil
    ) {
        self.mode = mode
        self.title = title
        self.titleScript = titleScript
        self.titleRefreshInterval = titleRefreshInterval
        self.actionScript = actionScript
        self.shortcutKey = shortcutKey
        self.jobScript = jobScript
        self.reloadJob = reloadJob
        self.autostartJob = autostartJob
    }
    
    @objc func startJob() {
        self.currentJob?.terminate()

        if let script = self.jobScript {
            script.execute (launched: {
                process in
                
                self.currentJob = process
                
                if let title = self.title {
                    self.updateTitle(title: title)
                }
                self.jobStatusItem?.title = "running - pid:\(process.processIdentifier)"
            }, completed: {
                status, result in
                
                self.jobStatusItem?.title = "exited: \(status)"
                
                if let title = self.title {
                    self.updateTitle(title: title)
                }
                
                if let reloadJob = self.reloadJob, reloadJob {
                    self.startJob()
                }
            })
        }
    }

    @objc func stopJob() {
        self.reloadJob = false
        self.currentJob?.terminate()
    }
    
    func updateTitle(title: String) {
        if self.mode == .JobStatus {
            var color = NSColor.gray
            
            // Update job's status label
            if let currentJob = self.currentJob {
                if currentJob.isRunning {
                    color = NSColor.green
                } else if currentJob.terminationStatus != 0 {
                    color = NSColor.red
                }
            }
            
            let mutableAttributedString = NSMutableAttributedString(string: "●", attributes: [
                NSAttributedString.Key.foregroundColor: color
            ])
            
            mutableAttributedString.append(NSAttributedString(string: " " + title))
            menuItem?.attributedTitle = mutableAttributedString
        } else {
            menuItem?.title = title
        }
    }

    func createMenuItem(_ appDeletate: AppDelegate) -> NSMenuItem {
        let menuItem = NSMenuItem()
        
        if self.mode == .JobStatus {
            let subMenu = NSMenu()
            let statusItem = NSMenuItem(title: "stopped", action: nil, keyEquivalent: "")
            self.jobStatusItem = statusItem

            let startItem = NSMenuItem(title: "start", action: nil, keyEquivalent: "")
            startItem.action = #selector(ItemConfig.startJob)
            startItem.target = self
            
            let stopItem = NSMenuItem(title: "stop", action: nil, keyEquivalent: "")
            stopItem.action = #selector(ItemConfig.stopJob)
            stopItem.target = self
            
            let restartItem = NSMenuItem(title: "restart", action: nil, keyEquivalent: "")
            restartItem.action = #selector(ItemConfig.startJob)
            restartItem.target = self
            
            subMenu.addItem(statusItem)
            subMenu.addItem(startItem)
            subMenu.addItem(stopItem)
            subMenu.addItem(restartItem)

            menuItem.submenu = subMenu
            
            
            // Start the job if needed
            if let autoStart = self.autostartJob, autoStart {
                self.startJob()
            }
        } else if self.mode == .ApplicationQuit {
            menuItem.target = appDeletate
            menuItem.action = #selector(AppDelegate.terminateMenuBarApp(_:))
        } else if self.mode == .RefreshingItem {
            // Set up scripting
            if self.actionScript != nil {
                menuItem.target = self
                menuItem.action = #selector(ItemConfig.dispatchAction)
            }
        }
        
        // Shortcut key
        if let shortcutKey = self.shortcutKey {
            menuItem.keyEquivalent = shortcutKey
            menuItem.keyEquivalentModifierMask = .command
        }
        
        // Associate the menu item to the model
        self.menuItem = menuItem
        self.initializeTitle()
        return menuItem
    }
    
    /// Dispatch background script action
    @objc func dispatchAction() {
        if let script = self.actionScript {
            script.execute {
                _, result in
                
                print("Result: \(result)")
            }
        }
    }
    
    /// Initialize title bar
    func initializeTitle() {
        // 1. Set initial title.
        if let title = self.title {
            self.updateTitle(title: title)
        }

        // 2. Dispatch script for other title.
        if let titleScript = self.titleScript {
            titleScript.execute { [weak self] _, result in
                self?.menuItem?.title = result
            }
            
            // While we're executing the title script,
            // Also set up a timer if we need it.
            if let titleRefreshInterval = self.titleRefreshInterval {
                self.refreshTimer = Timer.scheduledTimer(withTimeInterval: titleRefreshInterval, repeats: true, block: {
                    timer in
                    
                    // In the future, execute the title updates
                    titleScript.execute { [weak self] _, result in
                        // Update in background.
                        self?.menuItem?.title = result
                        // Invalidate if self is no longer available (gc)
                        if self == nil {
                            timer.invalidate()
                        }
                    }
                })
            }
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuItems : [ItemConfig] = [
        ItemConfig(
            title: "IP Address",
            titleScript: Script(
                bin: "/bin/sh",
                args: ["-c", "echo IP: $(curl https://api.ipify.org)"],
                env: [
                    "PATH": "/usr/bin:/usr/local/bin:/sbin:/bin"
                ]),
            titleRefreshInterval: 120
        ),
        ItemConfig(
            title: "Setup Help",
            actionScript: Script(
                bin: "/bin/sh",
                args: ["-c", "open https://www.richinfante.com"],
                env: [
                    "PATH": "/usr/bin:/usr/local/bin:/sbin:/bin"
                ])
        ),
        ItemConfig(
            mode: .ApplicationQuit,
            title: "Quit",
            shortcutKey: "q"
        )
    ]

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let json = try? Data(contentsOf: URL(fileURLWithPath: "/Users/rich/.config/shbar/shbar.json"))
        if let json = json {
            let decoder = JSONDecoder()
            let decodedItems = try? decoder.decode([ItemConfig].self, from: json)

            if let decodedItems = decodedItems {
                print("Loaded from File!")
                menuItems = decodedItems
            }
        } else {
            print("No config file present!")
        }

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted

        let data = try? jsonEncoder.encode(menuItems)
        print(String(data: data!, encoding: .utf8)!)
        // Insert code here to initialize your application
        let menu = NSMenu(title: "shbar")
        menu.items = []
        
        for item in menuItems {
            // Add to actual menu
            menu.items.append(item.createMenuItem(self))
        }

        // Set main title
        statusItem.button!.title = "shbar"
        statusItem.menu = menu
        print("launched.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
        // Insert code here to tear down your application
    }
    
    @objc func terminateMenuBarApp(_ sender: NSMenuItem?) {
        // Terminate jobs
        for item in menuItems {
            item.currentJob?.terminate()
        }

        NSApplication.shared.terminate(self)
    }


}

