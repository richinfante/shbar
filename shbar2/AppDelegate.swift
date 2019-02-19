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
    ]

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

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

