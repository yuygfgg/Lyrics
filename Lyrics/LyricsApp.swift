//
//  LyricsApp.swift
//  Lyrics
//
//  Created by Fang Liangchen on 2023/12/19.
//

import Foundation
import SwiftUI
import HotKey
import AlertToast
import Cocoa


/// A shared instance for managing user interface preferences.
class UIPreferences: ObservableObject {
    /// The shared instance of `UIPreferences`.
    static let shared = UIPreferences()
    
    /// The cover image for the background.
    @Published var coverImage: NSImage?
    
    /// The playback progress time interval.
    @Published var playbackProgress: TimeInterval = 0
    
    /// A boolean indicating whether the cover image is visible.
    @Published var isCoverImageVisible: Bool = isCoverImageVisibleConfig()
    
    /// A boolean indicating whether the playback progress is visible.
    @Published var isPlaybackProgressVisible: Bool = isPlaybackProgressVisibleConfig()
    
    @Published var willAutoCreateArtistDirectory: Bool = autoCreateArtistDirectory()
    
    /// A boolean indicating whether the window is sticky.
    @Published var isWindowSticky: Bool = false
    
    
    /// A boolean flag indicating whether the toast should be displayed or not.
    @Published var showToast: Bool = false;
    
    /// The text content of the toast message.
    @Published var toastText: String = "";
    
    /// The type of the toast, which determines its appearance and behavior.
    @Published var toastType: AlertToast.AlertType = .regular;
}


/// AppDelegate class responsible for managing the application's lifecycle.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// The main window of the application.
    var window: NSWindow!
    
    /// Subwindow dedicated to searching for lyrics.
    var subwindow: NSWindow!
    
    //StatusBar to show lyrics.
    var statusBarItem: NSStatusItem?
    
    /// Called when the application finishes launching.
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        
        initializeLyrics(withDefault: [
            LyricInfo(id: 0, text: "Not playing.", isCurrent: false, playbackTime: 0, isTranslation: false),
        ])
        
        registerNotifications()
        
        // Create and configure the main window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        
        // Create a visual effect view for the window
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .dark
        
        // Create a hosting view for the SwiftUI content
        let hostingView = NSHostingView(rootView: LyricsView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hostingView)
        
        // Set up constraints for the hosting view
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
        
        // Set the content view of the window to the visual effect view
        window.contentView = visualEffectView
        
        // Make the window titlebar transparent.
        window.titlebarAppearsTransparent = true
        
        // Hide the zoom button in the top-left corner of the window.
        window.standardWindowButton(NSWindow.ButtonType.zoomButton)!.isHidden = true
        
        // Hide the minimize button in the top-left corner of the window.
        //        window.standardWindowButton(NSWindow.ButtonType.miniaturizeButton)!.isHidden = true
        
        // Center the window on the screen.
        window.center()
        
        // Allow moving the window by interacting with the background.
        window.isMovableByWindowBackground = true
        
        // Set a unique name for saving the window's frame position and size.
        window.setFrameAutosaveName("LyricsWindow")
        
        // Make the window key and order it to the front.
        window.makeKeyAndOrderFront(nil)
        
        // Remove the resizable style mask to disable resizing the window.
        window.styleMask.remove(.resizable)
        
        
    }
    
    //init status bar
    func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.title = "歌词加载中..."
        }
        NotificationCenter.default.addObserver(self, selector: #selector(updateStatusBar(_:)), name: NSNotification.Name("UpdateStatusBar"), object: nil)
    }

    //do status bar update
    @objc func updateStatusBar(_ notification: Notification) {
        if let lyric = notification.userInfo?["lyric"] as? String, let button = statusBarItem?.button {
            button.title = lyric
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let item = statusBarItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }
    
    
    /// Determines whether the application should terminate after the last window is closed.
    ///
    /// - Parameter sender: The NSApplication instance.
    /// - Returns: `true` if the application should terminate after the last window is closed; otherwise, `false`.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    
    /// Toggles the stickiness of the main window.
    /// - Parameter sender: The object that triggered the action.
    @objc func toggleWindowSticky(_ sender: Any?) {
        if let window = NSApplication.shared.windows.first {
            window.level = (window.level == .floating) ? .normal : .floating
            UIPreferences.shared.isWindowSticky = (window.level == .floating)
        } else {
            debugPrint("Window topping failure.")
        }
    }
    
    
    /// Shows the subwindow for searching lyrics if it is not already visible.
    /// - Parameter sender: The object that triggered the action (e.g., a menu item).
    @objc func showSubwindow(_ sender: Any?) {
        // Check if the subwindow is already visible
        guard subwindow == nil else {
            
            // If the subwindow is already visible, activate it
            subwindow.makeKeyAndOrderFront(nil)
            
            return
        }
        
        // Create and configure the subwindow
        subwindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        
        // Set up the content view with the SubWindowView
        let subwindowView = LyricsSearchView() {
            self.closeSubwindow()
        }
        
        // Set the content view of the subwindow
        subwindow.contentView = NSHostingView(rootView: subwindowView)
        
        // Show the subwindow
        subwindow.center()
        
        subwindow.makeKeyAndOrderFront(nil)
        
        subwindow.title = "Search Lyrics"
    }
    
    
    /// Closes the subwindow used for searching lyrics.
    func closeSubwindow() {
        subwindow = nil
    }
    
}


/// Adjusts the start time to make the lyrics display 1 second faster.
func handle1SecondFaster() {
    startTime -= 1
    showRegularToast("Fast-forward one second.")
}


/// Adjusts the start time to make the lyrics display 1 second slower.
func handle1SecondSlower() {
    startTime += 1
    showRegularToast("Rewind one second.")
}


/**
 Handles the recalibration process.
 
 This function stops displaying lyrics and then starts displaying lyrics again.
 */
func handleRecalibration() {
    
    getNowPlayingInfo { nowPlayingInfo in
        // Check if the now playing information is empty
        guard !nowPlayingInfo.isEmpty else {
            showRegularToast("Now playing information is empty.")
            return
        }
        
        // Extract artist and title
        let artist = nowPlayingInfo["Artist"] as? String ?? ""
        let title = nowPlayingInfo["Title"] as? String ?? ""
        let track = "\(artist) - \(title)"
        
        // Check if the current track is nil or if it's the same as the new track
        if currentTrack == nil {
            currentTrack = track
            currentTrackArtist = artist
            currentTrackTitle = title
            return
        }
        
        if track == currentTrack {
            return
        } else {
            currentTrack = track
            currentTrackArtist = artist
            currentTrackTitle = title
        }
        
        

    }
    
    
    
    // Check playback state
    getPlaybackState { isPlaying in
        
        if isPlaying {
            // Stop displaying lyrics
            stopLyrics()
            
            // Start displaying lyrics
            startLyrics()
            
            // Show a successful Toast notification
            showRegularToast("Recalibration successful.")
        } else {
            showRegularToast("Not playing.")
        }
    }

    

}

/// Handles manual input for calibration.
func handleManualCalibration() {
    NSApp.activate(ignoringOtherApps: true)
    showInputAlert(
        title: "Manual Calibration",
        message: "Enter the time adjustment value (e.g., +0.5 or -0.5). Positive values speed up the playback, and negative values slow down the playback.",
        defaultValue: "-1.5",
        onFirstButtonTap: { input in
            guard let adjustment = TimeInterval(input) else {
                showAlert(title: "Manual Calibration", message: "Please enter a valid numeric value.")
                return
            }
            startTime -= adjustment
            showRegularToast("Adjusted by \(adjustment) seconds.")
        }
    )
}


/**
 Handles the configuration of the global offset.
 
 This function activates the application, shows an input alert to set the adjustment value for the delay
 in displaying lyrics globally, and saves the configuration to UserDefaults.
 */
func handleConfigureGlobalOffset() {
    // Activate the application
    NSApp.activate(ignoringOtherApps: true)
    
    // Show an input alert for setting the global offset
    showInputAlert(
        title: "Configure Global Offset",
        message: "Enter an offset for the global lyrics display (usually 1 second faster).",
        defaultValue: "\(getGlobalOffsetConfig())",
        onFirstButtonTap: { input in
            
            // Convert the input to TimeInterval
            guard let adjustment = TimeInterval(input) else {
                
                // Show an alert for invalid input
                showAlert(title: "Global Offset", message: "Please enter a valid numeric value.")
                return
            }
            
            // Save the adjustment value to UserDefaults
            UserDefaults.standard.set(adjustment, forKey: "GlobalOffset")
            
            // Show a success alert
            showAlert(title: "Settings Saved", message: "Global offset has been successfully set.")
        }
    )
}


/// Handles configuring the player.
func handleConfigurePlayer() {
    let playerNameConfig = getPlayerNameConfig()
    showInputAlert(title: "Configure Player",
                   message: "Enter the app bundle identifier of your player.",
                   defaultValue: playerNameConfig,
                   onFirstButtonTap: { inputText in
        UserDefaults.standard.set(inputText, forKey: "PlayerPackageName")
        showAlert(title: "Settings Saved", message: "Changes will take effect after restarting the application.", firstButtonTitle: "Restart", onFirstButtonTap: { restartApp() }, showCancelButton: true)
    })
}


/// Handles configuring the lyrics folder.
func handleConfigureLyricsFolder() {
    let lyricsFolderPathConfig = getLyricsFolderPathConfig()
    showFolderPicker(message: "Choose the lyrics folder, the current path is: \(lyricsFolderPathConfig)", defaultFolderPath: lyricsFolderPathConfig) { selectedFolderPath in
        if var folderPath = selectedFolderPath {
            if !folderPath.hasSuffix("/") {
                folderPath.append("/")
            }
            UserDefaults.standard.set(folderPath, forKey: "LyricsFolder")
            showAlert(title: "Settings Saved", message: "Lyrics folder has been successfully set: \(getLyricsFolderPathConfig())")
        }
    }
}

/// Opens the lyrics search window.
func handleSearchLyrics() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(#selector(AppDelegate.showSubwindow(_:)), to: nil, from: nil)
}


/// Handles toggling sticky window.
func handleToggleSticky(isEnabled: Bool) {
    NSApp.activate(ignoringOtherApps: true)
    UIPreferences.shared.isWindowSticky = isEnabled
    NSApp.sendAction(#selector(AppDelegate.toggleWindowSticky(_:)), to: nil, from: nil)
    debugPrint("isWindowSticky=\(UIPreferences.shared.isWindowSticky)")
    
    // Show a Toast notification
    let toastMessage = UIPreferences.shared.isWindowSticky ? "Window is now sticky." : "Window is no longer sticky."
    showRegularToast(toastMessage)
}


/// Handles toggling show album cover.
func handleToggleShowAlbumCover(isEnabled: Bool) {
    UIPreferences.shared.isCoverImageVisible = isEnabled
    debugPrint("isCoverImageVisible=\(UIPreferences.shared.isCoverImageVisible)")
    if (!UIPreferences.shared.isCoverImageVisible) {
        UIPreferences.shared.coverImage = nil
        UserDefaults.standard.set(false, forKey: "IsCoverImageVisible")
    } else {
        updateAlbumCover()
        UserDefaults.standard.set(true, forKey: "IsCoverImageVisible")
    }
}

/// Handles toggling show playback progress.
func handleToggleShowPlaybackProgress(isEnabled: Bool) {
    UIPreferences.shared.isPlaybackProgressVisible = isEnabled
    debugPrint("isPlaybackProgressVisible=\(UIPreferences.shared.isPlaybackProgressVisible)")
    UserDefaults.standard.set(UIPreferences.shared.isPlaybackProgressVisible, forKey: "IsPlaybackProgressVisible")
}

func handleToggleAutoCreateArtistDirectory(isEnabled: Bool) {
    UIPreferences.shared.willAutoCreateArtistDirectory = isEnabled
    debugPrint("willAutoCreateArtistDirectory=\(UIPreferences.shared.willAutoCreateArtistDirectory)")
    UserDefaults.standard.set(UIPreferences.shared.willAutoCreateArtistDirectory, forKey: "autoCreateArtistDirectory")
}

func handleActivateApp() {
    // 如果窗口最小化，先将窗口还原
    if let window = NSApp.windows.first {
        if (!window.isVisible) {
            window.deminiaturize(nil)
        }
    }
    
    // 激活应用程序
    NSApp.activate(ignoringOtherApps: true)
}


// The main entry point for the LyricsApp.
@main
struct LyricsApp: App {
    
    // Define a hotkey for the application
    let hotKey = HotKey(key: .l, modifiers: [.control], keyDownHandler: handleActivateApp)
    //    let hotKey = HotKey(key: .l, modifiers: [.control], keyDownHandler: {NSApp.activate(ignoringOtherApps: true)})
    
    // The app delegate for managing the application's lifecycle.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @ObservedObject private var uiPreferences = UIPreferences.shared
    
    // The body of the app scene.
    var body: some Scene {
        // Settings scene
        Settings {
            EmptyView()
        }
        .commands {
            CommandMenu("Display") {
                Toggle("Toggle Sticky", isOn: Binding<Bool>(
                    get: {
                        return uiPreferences.isWindowSticky
                    },
                    set: { isEnabled in
                        handleToggleSticky(isEnabled: isEnabled)
                    }
                ))
                Toggle("Show Album Cover", isOn: Binding<Bool>(
                    get: {
                        return uiPreferences.isCoverImageVisible
                    },
                    set: { isEnabled in
                        handleToggleShowAlbumCover(isEnabled: isEnabled)
                    }
                ))
                Toggle("Show Playback Progress", isOn: Binding<Bool>(
                    get: {
                        return uiPreferences.isPlaybackProgressVisible
                    },
                    set: { isEnabled in
                        handleToggleShowPlaybackProgress(isEnabled: isEnabled)
                    }
                ))
            }
            CommandMenu("Playback") {
                Button("1 Second Faster") { handle1SecondFaster() }.keyboardShortcut("+")
                Button("1 Second Slower") { handle1SecondSlower() }.keyboardShortcut("-")
                Button("Manual Calibration") { handleManualCalibration() }
            }
            CommandMenu("Settings") {
                Button("Configure Player") { handleConfigurePlayer() }
                Button("Configure Lyrics Folder") { handleConfigureLyricsFolder() }
                Button("Configure Global Offset") { handleConfigureGlobalOffset() }
                Toggle("Auto Create Artist Directory", isOn: Binding<Bool>(
                    get: {
                        return uiPreferences.willAutoCreateArtistDirectory
                    },
                    set: { isEnabled in
                        handleToggleAutoCreateArtistDirectory(isEnabled: isEnabled)
                    }
                ))
            }
            CommandMenu("Utilities") {
                Button("Search Lyrics") { handleSearchLyrics() }.keyboardShortcut("s")
            }
        }
    }
}

extension LyricsViewModel {
    //update statusbar lyrics
    func updateStatusBar(with lyric: String) {
        debugPrint("update bar with \(lyric)")
        NotificationCenter.default.post(name: NSNotification.Name("UpdateStatusBar"), object: nil, userInfo: ["lyric": lyric])
    }
}
