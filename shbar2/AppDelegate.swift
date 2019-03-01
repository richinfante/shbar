//
//  AppDelegate.swift
//  shbar2
//
//  Created by Rich Infante on 2/14/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuItems : [ItemConfig] = [
        ItemConfig(
            title: "IP Address",
            titleScript: Script(
                bin: "/bin/sh",
                args: ["-c", "echo $(curl https://api.ipify.org) | tr '\n' ' '"],
                env: [
                    "PATH": "/usr/bin:/usr/local/bin:/sbin:/bin"
                ]),
            titleRefreshInterval: 120,
            actionScript: Script(
                bin: "/bin/sh",
                args: ["-c", "open https://api.ipify.org"],
                env: [
                    "PATH": "/usr/bin:/usr/local/bin:/sbin:/bin"
                ])
        ),
        ItemConfig(
            title: "~:$",
            children: [
                ItemConfig(
                    title: "Setup Help",
                    actionScript: Script(
                        bin: "/bin/sh",
                        args: ["-c", "open https://github.com/richinfante/shbar"],
                        env: [
                            "PATH": "/usr/bin:/usr/local/bin:/sbin:/bin"
                        ])
                ),
                ItemConfig(
                    mode: .ApplicationQuit,
                    title: "Quit",
                    shortcutKey: "q"
                )
            ])
    ]

    var statusItems : [NSStatusItem] = []

    static var userHomeDirectoryPath : String {
        let pw = getpwuid(getuid())
        let home = pw?.pointee.pw_dir
        let homePath = FileManager.default.string(withFileSystemRepresentation: home!, length: Int(strlen(home)))
        
        return homePath
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(atPath: "\(AppDelegate.userHomeDirectoryPath)/.config/shbar", withIntermediateDirectories: true)
        } catch let error {
            print("Error creating config directory: \(error)")
        }
        
        do {
            try manager.createDirectory(atPath: "\(AppDelegate.userHomeDirectoryPath)/Library/Logs/shbar", withIntermediateDirectories: false)
        } catch let error {
            print("Error creating log directory: \(error)")
    }
        
        let json = try? Data(contentsOf: URL(fileURLWithPath: "\(AppDelegate.userHomeDirectoryPath)/.config/shbar/shbar.json"))
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

        for item in menuItems {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            // Set main title
            statusItem.menu = item.createSubMenu(self)
            item.menuItem = statusItem.button!
            item.initializeTitle()
            
            if item.actionScript != nil {
                statusItem.button!.action = #selector(ItemConfig.dispatchAction)
                statusItem.button!.target = item
            }
            
//            if item.menuItem?.title == "SHBAR" {
//                item.menuItem?.title = ""
//                let image = NSImage(named: "Image-1")
////                image!.size = NSSize(width: NSStatusItem.squareLength, height: NSStatusItem.squareLength)
//                statusItem.length = NSStatusItem.squareLength
//                statusItem.button!.image = image
//            }
            
            statusItems.append(statusItem)
        }
        
        print("launched.")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        self.terminateRemainingJobs()
        return NSApplication.TerminateReply.terminateNow
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        self.terminateRemainingJobs()
    }
    
    func terminateRemainingJobs() {
        print("terminating remaining jobs...")
        
        // Terminate jobs
        for item in menuItems {
            item.currentJob?.terminate()
        }
    }

    @objc func terminateMenuBarApp(_ sender: NSMenuItem?) {
        self.terminateRemainingJobs()
        NSApplication.shared.terminate(self)
    }

    func handler(sig: Int32) -> Void {
        self.terminateMenuBarApp(nil)
    }

}

