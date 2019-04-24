//
//  AppDelegate.swift
//  shbar2
//
//  Created by Rich Infante on 2/14/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Cocoa
import Foundation
import UserNotifications

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    /// Store ids / itemconfig mappings.
    /// Used to translate jobs across notifications.
    var responderItems : [String:ItemConfig] = [:]
    
    
    /// Register a job with the responder dict.
    /// This allows for finding later with the returned ID.
    func registerProcessNotificationID(job: ItemConfig) -> String {
        let str = UUID.init().uuidString
        self.responderItems[str] = job
        return str
    }
    
    
    /// Get a process via it's ID
    func getProcessByNotificationID(id: String) -> ItemConfig? {
        return responderItems[id]
    }
    
    // Menu items to display. Set to default config with help.
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
                    title: "Show Config Folder",
                    actionScript: Script(
                        bin: "/bin/sh",
                        args: ["-c", "open \(AppDelegate.userHomeDirectoryPath)/.config/shbar/"],
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

    /// Get a link to the user's home path
    static var userHomeDirectoryPath : String {
        let pw = getpwuid(getuid())
        let home = pw?.pointee.pw_dir
        let homePath = FileManager.default.string(withFileSystemRepresentation: home!, length: Int(strlen(home)))
        
        return homePath
    }
    
    /// Handler for app launch.
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let manager = FileManager.default
        
        let restartAction = UNNotificationAction(identifier: "restart", title: "Restart", options: [])
        let logsAction = UNNotificationAction(identifier: "logs", title: "View Logs", options: [])
        
        let jobAlert = UNNotificationCategory(identifier: "jobAlert", actions: [restartAction, logsAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([jobAlert])
    
        
        // Create config directory
        do {
            try manager.createDirectory(atPath: "\(AppDelegate.userHomeDirectoryPath)/.config/shbar", withIntermediateDirectories: true)
        } catch let error {
            print("Error creating config directory: \(error)")
        }
        
        // Create log directory
        do {
            try manager.createDirectory(atPath: "\(AppDelegate.userHomeDirectoryPath)/Library/Logs/shbar", withIntermediateDirectories: false)
        } catch let error {
            print("Error creating log directory: \(error)")
        }
        
        // Attempt to decode the JSON config file.
        let json = try? Data(contentsOf: URL(fileURLWithPath: "\(AppDelegate.userHomeDirectoryPath)/.config/shbar/shbar.json"))
        
        // If load works, try to decode into an itemconfig.
        if let json = json {
            let decoder = JSONDecoder()
            let decodedItems = try? decoder.decode([ItemConfig].self, from: json)

            // Assign the new items into the global item list.
            if let decodedItems = decodedItems {
                print("Loaded from File!")
                menuItems = decodedItems
            }
        } else {
            print("No config file present!")
        }

        // Next, pretty-print and format the current config.
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted

        // Print the config out.
        let data = try? jsonEncoder.encode(menuItems)
        print(String(data: data!, encoding: .utf8)!)

        
        // Initialize the menu items.
        for item in menuItems {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            // Set main title
            statusItem.menu = item.createSubMenu(self)
            item.menuItem = statusItem.button!
            item.initializeTitle()
            
            // Set up action to dispatch a script.
            if item.actionScript != nil {
                statusItem.button!.action = #selector(ItemConfig.dispatchAction)
                statusItem.button!.target = item
            }
            
            // TODO: why is this incorrectly sized?
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
            item.currentJob?.interrupt()
            item.currentJob?.terminate()
        }
        
        print("termination complete.")
    }

    @objc func terminateMenuBarApp(_ sender: NSMenuItem?) {
        self.terminateRemainingJobs()
        NSApplication.shared.terminate(self)
    }
    
    /// Allow in-app notifications (for when menu is focused)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        completionHandler([.alert, .sound, .badge])
    }
    
    /// Enable message handling.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler:
        @escaping () -> Void) {
        // Get the meeting ID from the original notification.
        let userInfo = response.notification.request.content.userInfo
        
        // Try to get Job notification ID
        if let id = userInfo["job"] as? String {

            // Try to find associated job.
            if let job = self.getProcessByNotificationID(id: id) {
                
                // Parse actions
                if response.notification.request.content.categoryIdentifier == "jobAlert" {
                    if response.actionIdentifier == "logs" {
                        job.showJobConsole()
                    }
                    
                    if response.actionIdentifier == "restart" || response.actionIdentifier == "start"{
                        job.startJob()
                    }
                }
            } else {
                print("Can't find Job.")
            }
        } else {
            print("No job ID!")
        }
            
        completionHandler()
    }
}

