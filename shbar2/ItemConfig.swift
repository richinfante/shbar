//
//  ItemConfig.swift
//  shbar2
//
//  Created by Rich Infante on 2/18/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Cocoa
import Foundation
import UserNotifications

class ItemConfig : Codable {
    /// The mode for the menu item.
    var mode: ItemConfigMode? = .RefreshingItem
    
    /// Display title
    var title: String?
    
    /// Title script to run.
    var titleScript: Script?
    
    /// Refresh interval for the title.
    var titleRefreshInterval: TimeInterval?
    
    /// Script to un on click.
    var actionScript: Script?
    
    /// Shortcut key for the menu item
    var shortcutKey: String?
    
    /// For Job-Type Items, the job script.
    var jobScript: Script?
    
    /// Should we auto-reload the job when it fails?
    var reloadJob: Bool?
    
    /// Should we auto-start the job on startup.
    var autostartJob: Bool?
    
    /// Attachment to the menu label for updating text.
    /// This is a commmon protocol adapter for different types of system labels.
    var menuItem: LabelProtocol?
    
    /// Timer scheduling refresh events.
    var refreshTimer: Timer?
    
    /// Job status menu item - for jobs with status, this is a label to show "running"/"suspended"/etc.. states.
    var jobStatusItem: NSMenuItem?
    
    /// The exit status from the job.
    var jobExitStatus: Int32?

    /// The currently runnin job process
    var currentJob: Process?

    /// Is the job paused?
    var isPaused : Bool = false

    /// Is the action a console show?
    var actionShowsConsole: Bool? = false

    /// Children of this item.
    var children: [ItemConfig]? = []

    /// Menu item for the start job button
    var startMenuItem: NSMenuItem?

    /// Menu item for the stop job button
    var stopMenuItem: NSMenuItem?

    /// Menu item for the restart job button
    var restartMenuItem: NSMenuItem?

    /// Menu item for the suspend job button
    var suspendMenuItem: NSMenuItem?

    /// Menu item for the resume job button
    var resumeMenuItem: NSMenuItem?
    
    /// Menu item for the showing console of job.
    var consoleMenuItem: NSMenuItem?
    
    var delegate: AppDelegate?
    
    /// Keys to encode / decode for direct-to-config (de)serialization
    private enum CodingKeys: String, CodingKey {
        case mode
        case children
        case title
        case titleScript
        case titleRefreshInterval
        case actionScript
        case shortcutKey
        case jobScript
        case reloadJob
        case autostartJob
        case actionShowsConsole
    }
    
    /// Initializer for building in-code.
    /// Primarily for demo ui.
    init(
        mode: ItemConfigMode? = .RefreshingItem,
        title: String? = nil,
        titleScript: Script? = nil,
        titleRefreshInterval: TimeInterval? = nil,
        actionScript: Script? = nil,
        jobScript: Script? = nil,
        reloadJob: Bool? = false,
        autostartJob: Bool? = false,
        shortcutKey: String? = nil,
        children: [ItemConfig]? = []
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
        self.children = children
    }
    
    /// Function for suspending the current job, if it's running.
    /// This updates the status labels.
    @objc func suspendJob() {
        if let process = self.currentJob {
            process.suspend()
            self.isPaused = true
            
            if let title = self.title {
                self.updateTitle(title: title)
            }
        }
    }

    /// Function for resuming the current job, if it's stopped.
    /// This updates the status labels.
    @objc func resumeJob() {
        if let process = self.currentJob {
            process.resume()
            self.isPaused = false
            
            if let title = self.title {
                self.updateTitle(title: title)
            }
        }
    }
    
    /// Function for starting the current job, if it's not running.
    /// Running jobs are first killed.
    /// This updates the status labels.
    @objc func startJob() {
        self.currentJob?.interrupt()
        self.currentJob?.terminate()
        
        if let script = self.jobScript {
            script.launchJob (launched: {
                process in
                
                self.currentJob = process
                
                if let title = self.title {
                    self.updateTitle(title: title)
                }
            }, completed: {
                status in
                
                // Register for notifications if we have a delegate.
                if let delegate = self.delegate {
                    let id = delegate.registerProcessNotificationID(job: self)
                    
                    // Create content
                    let content = UNMutableNotificationContent()
                    content.title = "\(self.title ?? "Process")"
                    content.categoryIdentifier = "jobAlert"
                    
                    // Show info for auto-restarts.
                    if self.reloadJob == true {
                        content.body = "Auto-Restarted; Exited with code: \(status)"
                    } else {
                        content.body = "Exited with code: \(status)"
                    }
                    
                    content.sound = UNNotificationSound.default
                    content.userInfo = [ "job": id ]

                    // Trigger after 0.1s.
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                    
                    // Schedule request.
                    let request = UNNotificationRequest(identifier: "localNotification", content: content, trigger: trigger)
                    
                    // Set delegate and add.
                    UNUserNotificationCenter.current().delegate = self.delegate
                    UNUserNotificationCenter.current().add(request) { (error) in
                        print(error)
                    }
                }
                
                // update title
                if let title = self.title {
                    self.updateTitle(title: title)
                }
                
                // Reload if needed.
                if let reloadJob = self.reloadJob, reloadJob {
                    self.startJob()
                }
            })
        }
    }
    
    /// Stop a job.
    @objc func stopJob() {
        self.reloadJob = false
        if let job = self.currentJob {
            job.terminate()
            self.currentJob = nil

            if let title = self.title {
                self.updateTitle(title: title)
            }
            
            print("Terminate current job: \(job.processIdentifier)")
        } else {
            print("Cannot terminate: no job running.")
        }
    }
    
    /// Show console.
    @objc func showJobConsole() {
        if let jobScript = self.jobScript, let uuid = jobScript.uuid {
            DispatchQueue.global(qos: .background).async {
                let process = Process()
                process.arguments = ["\(AppDelegate.userHomeDirectoryPath)/Library/Logs/shbar/\(uuid.uuidString).log"]
                process.launchPath = "/usr/bin/open"
                process.launch()
            }
        } else {
            print("Failed to show console")
        }
    }
    
    /// Update title / job status.
    func updateTitle(title: String) {
        if self.mode == .JobStatus {
            var color = NSColor.gray
            
            // Update job's status label
            if let currentJob = self.currentJob {
                // Determine color depending on status
                if self.isPaused {
                    color = NSColor.blue
                } else if currentJob.isRunning {
                    color = NSColor.green
                } else if currentJob.terminationStatus != 0 {
                    color = NSColor.red
                }
                
                // Update job control menu items
                if self.isPaused {
                    self.startMenuItem?.isEnabled = false
                    self.stopMenuItem?.isEnabled = true
                    self.restartMenuItem?.isEnabled = false
                    self.suspendMenuItem?.isEnabled = false
                    self.resumeMenuItem?.isEnabled = true
                    self.consoleMenuItem?.isEnabled = true
                    self.jobStatusItem?.title = "suspended - pid:\(currentJob.processIdentifier)"
                } else if currentJob.isRunning {
                    self.startMenuItem?.isEnabled = false
                    self.stopMenuItem?.isEnabled = true
                    self.restartMenuItem?.isEnabled = true
                    self.suspendMenuItem?.isEnabled = true
                    self.resumeMenuItem?.isEnabled = false
                    self.consoleMenuItem?.isEnabled = true
                    self.jobStatusItem?.title = "running - pid:\(currentJob.processIdentifier)"
                } else {
                    self.startMenuItem?.isEnabled = true
                    self.stopMenuItem?.isEnabled = false
                    self.restartMenuItem?.isEnabled = false
                    self.suspendMenuItem?.isEnabled = false
                    self.resumeMenuItem?.isEnabled = false
                    self.consoleMenuItem?.isEnabled = true
                    self.jobStatusItem?.title = "exited: \(currentJob.terminationStatus)"
                }
            } else {
                self.jobStatusItem?.title = "inactive"
                self.consoleMenuItem?.isEnabled = false
                self.startMenuItem?.isEnabled = true
                self.stopMenuItem?.isEnabled = false
                self.restartMenuItem?.isEnabled = false
                self.suspendMenuItem?.isEnabled = false
                self.resumeMenuItem?.isEnabled = false
                self.consoleMenuItem?.isEnabled = false
            }
            
            // Create status bullet
            let mutableAttributedString = NSMutableAttributedString(string: "●", attributes: [
                NSAttributedString.Key.foregroundColor: color
            ])
            
            // Assign title
            mutableAttributedString.append(NSAttributedString(string: " " + title))
            menuItem?.attributedTitleString = mutableAttributedString
        } else {
            if menuItem?.allowsNewlines == true {
                menuItem?.title = title
            } else {
                menuItem?.title = title.replacingOccurrences(of: "\n", with: " ")
            }
        }
    }
    
    
    /// Generate the submenu for this item
    // If it has none, nil is returned.
    func createSubMenu(_ appDelegate: AppDelegate) -> NSMenu? {
        self.delegate = appDelegate
        if let children = self.children, children.count > 0 {
            let subMenu = NSMenu()
            subMenu.autoenablesItems = true
            
            for item in children {
                subMenu.addItem(item.createMenuItem(appDelegate))
            }
            
            return subMenu
        }
        
        if self.mode == .JobStatus {
            let subMenu = NSMenu()
            subMenu.autoenablesItems = false
            
            let statusItem = NSMenuItem(title: "stopped", action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            self.jobStatusItem = statusItem
            
            let startItem = NSMenuItem(title: "Start Job", action: nil, keyEquivalent: "")
            startItem.action = #selector(ItemConfig.startJob)
            startItem.isEnabled = true
            startItem.target = self
            
            let stopItem = NSMenuItem(title: "Stop Job", action: nil, keyEquivalent: "")
            stopItem.action = #selector(ItemConfig.stopJob)
            stopItem.isEnabled = false
            stopItem.target = self
            
            let restartItem = NSMenuItem(title: "Restart Job", action: nil, keyEquivalent: "")
            restartItem.action = #selector(ItemConfig.startJob)
            restartItem.isEnabled = false
            restartItem.target = self
            
            let suspendItem = NSMenuItem(title: "Suspend Job", action: nil, keyEquivalent: "")
            suspendItem.action = #selector(ItemConfig.suspendJob)
            suspendItem.isEnabled = false
            suspendItem.target = self
            
            let resumeItem = NSMenuItem(title: "Resume Job", action: nil, keyEquivalent: "")
            resumeItem.action = #selector(ItemConfig.resumeJob)
            resumeItem.isEnabled = false
            resumeItem.target = self
            
            let consoleItem = NSMenuItem(title: "View Console", action: nil, keyEquivalent: "")
            consoleItem.action = #selector(ItemConfig.showJobConsole)
            consoleItem.isEnabled = true
            consoleItem.target = self
            
            subMenu.addItem(statusItem)
            subMenu.addItem(NSMenuItem.separator())
            subMenu.addItem(consoleItem)
            subMenu.addItem(NSMenuItem.separator())
            subMenu.addItem(startItem)
            subMenu.addItem(stopItem)
            subMenu.addItem(restartItem)
            subMenu.addItem(suspendItem)
            subMenu.addItem(resumeItem)
            
            self.startMenuItem = startItem
            self.stopMenuItem = stopItem
            self.restartMenuItem = restartItem
            self.suspendMenuItem = suspendItem
            self.resumeMenuItem = resumeItem
            self.consoleMenuItem = consoleItem
            
            return subMenu
        }
        
        return nil
    }
    
    /// Create a menu item for this.
    func createMenuItem(_ appDelegate: AppDelegate) -> NSMenuItem {
        let menuItem = NSMenuItem()
        self.delegate = appDelegate
        
        let subMenu = self.createSubMenu(appDelegate)
        
        if let subMenu = subMenu {
            menuItem.submenu = subMenu
        } else if self.mode == .ApplicationQuit {
            menuItem.target = appDelegate
            menuItem.action = #selector(AppDelegate.terminateMenuBarApp(_:))
        } else if self.mode == .RefreshingItem {
            // Set up scripting
            if self.actionScript != nil {
                menuItem.target = self
                menuItem.action = #selector(ItemConfig.dispatchAction)
            }
        }
        
        // Start the job if needed
        if let autoStart = self.autostartJob, autoStart {
            self.startJob()
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
            script.launchJob(launched: {
                process in
                self.currentJob = process
                if let show = self.actionShowsConsole, show {
                    self.showJobConsole()
                }
            }, completed: {
                result in
                
                print("Result: \(result)")
            })
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
                        print(result)
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
