//
//  AppDelegate.swift
//  shbar2
//
//  Created by Rich Infante on 2/14/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Cocoa
import Foundation

class Script {
    var bin: String
    var args: [String]
    var env: [String:String]
    
    init (bin: String, args:[String], env: [String:String]) {
        self.bin = bin
        self.args = args
        self.env = env
    }
    
    func execute(cb: ((String)->())?) {
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
            task.waitUntilExit()
            let status = task.terminationStatus
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String
            print("Child process exited with code \(status)")
            DispatchQueue.main.async {
                if let cb = cb {
                    cb(output)
                }
            }
        }
    }
}

enum ItemConfigMode {
    case RefreshingItem
    case JobStatus
}

class ItemConfig {
    var mode: ItemConfigMode = .RefreshingItem
    var title: String?
    var titleScript: Script?
    var titleRefreshInterval: TimeInterval?
    var actionScript: Script?
    var menuItem: NSMenuItem?
    var refreshTimer: Timer?
    
    init(
        mode: ItemConfigMode = .RefreshingItem,
        title: String? = nil,
        titleScript: Script? = nil,
        titleRefreshInterval: TimeInterval? = nil,
        actionScript: Script?,
        menuItem: NSMenuItem?
    ) {
        self.mode = mode
        self.title = title
        self.titleScript = titleScript
        self.titleRefreshInterval = titleRefreshInterval
        self.actionScript = actionScript
        self.menuItem = menuItem
    }
    
    /// Dispatch background script action
    @objc func dispatchAction() {
        if let script = self.actionScript {
            script.execute {
                string in
                
                print("Result: \(string)")
            }
        }
    }
    
    /// Initialize title bar
    func initializeTitle() {
        // 1. Set initial title.
        if let title = self.title {
            self.menuItem?.title = title
        }

        // 2. Dispatch script for other title.
        if let titleScript = self.titleScript {
            titleScript.execute { [weak self] string in
                self?.menuItem?.title = string
            }
            
            // While we're executing the title script,
            // Also set up a timer if we need it.
            if let titleRefreshInterval = self.titleRefreshInterval {
                self.refreshTimer = Timer.scheduledTimer(withTimeInterval: titleRefreshInterval, repeats: true, block: {
                    timer in
                    
                    // In the future, execute the title updates
                    titleScript.execute { [weak self] string in
                        // Update in background.
                        self?.menuItem?.title = string
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
    
    let menuItems : [ItemConfig] = [
        ItemConfig(
            title: "IP Address",
            titleScript: Script(
                bin: "/bin/sh",
                args: ["-c", "echo IP: $(curl https://api.ipify.org)"],
                env: [
                    "PATH": "/usr/bin:/usr/local/bin:/sbin:/bin"
                ]),
            titleRefreshInterval: 120,
            actionScript: nil,
            menuItem: nil
        ),
        ItemConfig(
            title: "Run Alert",
            titleScript: nil,
            titleRefreshInterval: 1,
            actionScript:  Script(
                bin: "/bin/bash",
                args: ["-c", "wall <<< 'HI'"],
                env: [
                    "SHELL": "/bin/bash",
                    "HOME": "/Users/rich",
                    "PWD": "/Users/rich",
                    "LANG": "en_US.UTF-8",
                    "TMPDIR": "/tmp",
                    "PATH": "/usr/bin:/usr/local/bin:/sbin:/bin"
                ]),
            menuItem: nil
        )
    ]

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let menu = NSMenu(title: "shbar")
        menu.items = []
        
        for item in menuItems {
            let menuItem = NSMenuItem()
            
            if let title = item.title {
                menuItem.title = title
                
            }
            
            // Set up scripting
            if item.actionScript != nil {
                menuItem.target = item
                menuItem.action = #selector(ItemConfig.dispatchAction)
            }
            
            item.menuItem = menuItem
            item.initializeTitle()
            
            menu.items.append(menuItem)
        }
        
        menu.items.append(NSMenuItem(title: "Quit", action: #selector(self.quit(_:)), keyEquivalent: "q"))

        statusItem.button!.title = "shbar"
        statusItem.menu = menu
        print("launched.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
        // Insert code here to tear down your application
    }
    
    @objc func quit(_ sender: NSMenuItem?) {
        NSApplication.shared.terminate(self)
    }


}

