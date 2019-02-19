//
//  ItemConfig.swift
//  shbar2
//
//  Created by Rich Infante on 2/18/19.
//  Copyright © 2019 Rich Infante. All rights reserved.
//

import Cocoa
import Foundation

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
    var isPaused : Bool = false
    
    var startMenuItem: NSMenuItem?
    var stopMenuItem: NSMenuItem?
    var restartMenuItem: NSMenuItem?
    var suspendMenuItem: NSMenuItem?
    var resumeMenuItem: NSMenuItem?
    
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
    
    @objc func suspendJob() {
        if let process = self.currentJob {
            process.suspend()
            self.isPaused = true
            
            if let title = self.title {
                self.updateTitle(title: title)
            }
        }
    }
    
    @objc func resumeJob() {
        if let process = self.currentJob {
            process.resume()
            self.isPaused = false
            
            if let title = self.title {
                self.updateTitle(title: title)
            }
        }
    }
    
    @objc func startJob() {
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
    
    @objc func showJobConsole() {
        print("Show Job Console")
        if let jobScript = self.jobScript, let uuid = jobScript.uuid {
            print("Launch")
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
    
    func updateTitle(title: String) {
        if self.mode == .JobStatus {
            var color = NSColor.gray
            
            // Update job's status label
            if let currentJob = self.currentJob {
                if self.isPaused {
                    color = NSColor.blue
                } else if currentJob.isRunning {
                    color = NSColor.green
                } else if currentJob.terminationStatus != 0 {
                    color = NSColor.red
                }
                
                if self.isPaused {
                    //                    self.startMenuItem?.isHidden = true
                    //                    self.stopMenuItem?.isHidden = false
                    //                    self.restartMenuItem?.isHidden = false
                    //                    self.suspendMenuItem?.isHidden = true
                    //                    self.resumeMenuItem?.isHidden = false
                    self.jobStatusItem?.title = "suspended - pid:\(currentJob.processIdentifier)"
                } else if currentJob.isRunning {
                    //                    self.startMenuItem?.isHidden = true
                    //                    self.stopMenuItem?.isHidden = false
                    //                    self.restartMenuItem?.isHidden = false
                    //                    self.suspendMenuItem?.isHidden = false
                    //                    self.resumeMenuItem?.isHidden = true
                    self.jobStatusItem?.title = "running - pid:\(currentJob.processIdentifier)"
                } else {
                    //                    self.startMenuItem?.isHidden = false
                    //                    self.stopMenuItem?.isHidden = true
                    //                    self.restartMenuItem?.isHidden = true
                    //                    self.suspendMenuItem?.isHidden = true
                    //                    self.resumeMenuItem?.isHidden = false
                    self.jobStatusItem?.title = "exited: \(currentJob.terminationStatus)"
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
            
            let suspendItem = NSMenuItem(title: "suspend", action: nil, keyEquivalent: "")
            suspendItem.action = #selector(ItemConfig.suspendJob)
            suspendItem.target = self
            
            let resumeItem = NSMenuItem(title: "resume", action: nil, keyEquivalent: "")
            resumeItem.action = #selector(ItemConfig.resumeJob)
            resumeItem.target = self
            
            let consoleItem = NSMenuItem(title: "console", action: nil, keyEquivalent: "")
            consoleItem.action = #selector(ItemConfig.showJobConsole)
            consoleItem.target = self
            
            
            subMenu.addItem(statusItem)
            subMenu.addItem(startItem)
            subMenu.addItem(stopItem)
            subMenu.addItem(restartItem)
            subMenu.addItem(suspendItem)
            subMenu.addItem(resumeItem)
            subMenu.addItem(consoleItem)
            
            self.startMenuItem = startItem
            self.stopMenuItem = stopItem
            self.restartMenuItem = restartItem
            self.suspendMenuItem = suspendItem
            self.resumeMenuItem = resumeItem
            
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
