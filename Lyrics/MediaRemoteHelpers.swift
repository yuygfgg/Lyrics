//
//  MediaRemoteController.swift
//  Lyrics
//
//  Created by Fang Liangchen on 2023/12/19.
//

import Foundation
import Cocoa
import Dynamic


var currentTrack: String?
var currentTrackArtist: String?
var currentTrackTitle: String?


/// Enum representing different playback states for a media application.
enum PlaybackState: Int {
    /// The media application is terminated.
    case terminated = 0
    /// The media application is currently playing.
    case playing = 1
    /// The media application is paused.
    case paused = 2
    /// The media application is stopped.
    case stopped = 3
}


/**
 An enumeration representing media playback commands.
 
 - Case `kMRPlay`: Represents the command to play.
 - Case `kMRPause`: Represents the command to pause.
 - Case `kMRTogglePlayPause`: Represents the command to toggle between play and pause.
 - Case `kMRStop`: Represents the command to stop playback.
 - Case `kMRNextTrack`: Represents the command to skip to the next track.
 - Case `kMRPreviousTrack`: Represents the command to go back to the previous track.
 
 - Note: The raw values are integers starting from 0.
 */
enum MRCommand: Int {
    case kMRPlay = 0
    case kMRPause = 1
    case kMRTogglePlayPause = 2
    case kMRStop = 3
    case kMRNextTrack = 4
    case kMRPreviousTrack = 5
}


// Create a bundle for the MediaRemote framework
let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))

// Get function pointer for MRMediaRemoteGetNowPlayingInfo
let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString)
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
let MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)

// Get function pointer for MRMediaRemoteGetNowPlayingApplicationIsPlaying
let MRMediaRemoteGetNowPlayingApplicationIsPlayingPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString)
typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
let MRMediaRemoteGetNowPlayingApplicationIsPlaying = unsafeBitCast(MRMediaRemoteGetNowPlayingApplicationIsPlayingPointer, to: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction.self)

// Get function pointer for MRMediaRemoteRegisterForNowPlayingNotifications
let MRMediaRemoteRegisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString)
typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
let MRMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(MRMediaRemoteRegisterForNowPlayingNotificationsPointer, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)

// Get function pointer for MRMediaRemoteUnregisterForNowPlayingNotifications
let MRMediaRemoteUnregisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteUnregisterForNowPlayingNotifications" as CFString)
typealias MRMediaRemoteUnregisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
let MRMediaRemoteUnregisterForNowPlayingNotifications = unsafeBitCast(MRMediaRemoteUnregisterForNowPlayingNotificationsPointer, to: MRMediaRemoteUnregisterForNowPlayingNotificationsFunction.self)


// Get function pointer for MRMediaRemoteSendCommand
let MRMediaRemoteSendCommandPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString)
typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int, AnyObject?) -> Bool
let MRMediaRemoteSendCommand = unsafeBitCast(MRMediaRemoteSendCommandPointer, to: MRMediaRemoteSendCommandFunction.self)


/// Retrieves information about the currently playing media.
///
/// - Parameters:
///   - completion: A closure to be called once the now playing information is obtained.
///                  The closure takes a dictionary containing information such as artist,
///                  title, and elapsed time as parameters.
func getNowPlayingInfo(completion: @escaping ([String: Any]) -> Void) {
    var nowPlayingInfo: [String: Any] = [:]
    
    // Call the Media Remote framework to get now playing information
    MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { information in
        
        // Check if the information is empty
        if information.isEmpty {
            // Call the completion handler with an empty dictionary
            completion(nowPlayingInfo)
            return
        }
        // Check if the MRContentItem class can be obtained
        if let contentItemClass = objc_getClass("MRContentItem") as? MRContentItem.Type {
            // Attempt to create an instance of MRContentItem with nowPlayingInfo
            let item = contentItemClass.init(nowPlayingInfo: information)
            // Access calculated playback position from the metadata of the MRContentItem
            let calculatedPlaybackPosition = item?.metadata.calculatedPlaybackPosition
            // Print the calculated playback position
            debugPrint("calculatedPlaybackPosition=\(calculatedPlaybackPosition ?? 0.0)")
            // Update the nowPlayingInfo dictionary with the elapsed time
            nowPlayingInfo["ElapsedTime"] = calculatedPlaybackPosition ?? 0.0
        }
        
        // Extract information from the result
        nowPlayingInfo["Artist"] = information["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        nowPlayingInfo["Title"] = information["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        nowPlayingInfo["Album"] = information["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        //        nowPlayingInfo["ElapsedTime"] = information["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0.0
        
        if (UIPreferences.shared.isCoverImageVisible) {
            let artworkData = information["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            let artwork = artworkData.flatMap { NSImage(data: $0) }
            if (artwork == nil) {
                debugPrint("Artwork is nil.")
            } else if (artwork?.tiffRepresentation == UIPreferences.shared.coverImage?.tiffRepresentation) {
                debugPrint("Artwork has not changed, skipped.")
            } else {
                debugPrint("Artwork change detected, updated.")
                UIPreferences.shared.coverImage = artwork
            }
        }
        
        // Call the completion handler with the updated dictionary
        completion(nowPlayingInfo)
    }
}

func getCurrentSongDuration(completion: @escaping (TimeInterval?) -> Void) {
    MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main, { (info) in
        if let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber {
            completion(duration.doubleValue)
        } else {
            completion(nil)
        }
    })
}


/// Updates the album cover based on the currently playing media information.
func updateAlbumCover() {
    
    // Call the Media Remote framework to get now playing information
    MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { information in
        
        // Check if the information is empty
        if information.isEmpty {
            debugPrint("Now playing information is empty.")
            return
        }
        
        // Check if the cover image visibility is enabled
        if (UIPreferences.shared.isCoverImageVisible) {
            
            // Extract the artwork data from the now playing information
            let artworkData = information["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            
            // Create an NSImage from the artwork data
            let artwork = artworkData.flatMap { NSImage(data: $0) }
            
            // Set the background image in the shared ImageObject
            UIPreferences.shared.coverImage = artwork
        }
    }
}


/// Retrieves the playback state of the currently playing media application.
///
/// - Parameter completion: A closure to be called once the playback state is obtained.
///                         The closure takes a boolean parameter indicating whether
///                         the media application is currently playing or not.
func getPlaybackState(completion: @escaping (Bool) -> Void) {
    // Call the Media Remote framework to get the playback state
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(DispatchQueue.main) { isPlaying in
        // Call the completion handler with the obtained playback state
        completion(isPlaying)
    }
}


/// Handles the notification when the now playing information changes.
///
/// - Parameter notification: The notification object.
func handleNowPlayingInfoDidChangeNotification(notification: Notification) {
    getNowPlayingInfo { nowPlayingInfo in
        
        // Check if the now playing information is empty
        guard !nowPlayingInfo.isEmpty else {
            debugPrint("Now playing information is empty.")
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
            debugPrint("Track change detected: \(String(describing: currentTrack)) -> \(track)")
            currentTrack = track
            currentTrackArtist = artist
            currentTrackTitle = title
            
            // Check playback state
            getPlaybackState { isPlaying in
//                if isPlaying {
//                    sleep(1000000000)
                    startLyrics()
//                }
            }
        }
    }
}


/// Handles the change in playback state of the currently playing media application.
///
/// - Parameter notification: The notification object containing information about the playback state change.
func handleNowPlayingApplicationPlaybackStateDidChange(notification: Notification) {
    // Extract the raw playback state from the notification's user info
    let rawPlaybackState = notification.userInfo?["kMRMediaRemotePlaybackStateUserInfoKey"] as? Int ?? 3
    
    // Convert the raw playback state to a PlaybackState enum
    if let playbackState = PlaybackState(rawValue: rawPlaybackState) {
        // Print the detected playback state
        debugPrint("Playback state change detected: \(playbackState)")
        
        // Check the playback state and perform actions accordingly
        if playbackState == .playing {
            startLyrics()
        } else {
            stopLyrics()
        }
    }
}


/// Register for notifications related to system playback state and application lifecycle.
func registerNotifications() {
    
    // Bundle Identifier of the application to be monitored
    let targetAppBundleIdentifier = getPlayerNameConfig()
    
    if targetAppBundleIdentifier.isEmpty {
        debugPrint("No app bundle identifier set.")
        return
    }
    
    let notificationCenter = NotificationCenter.default
    
    // Register for Now Playing info change notification
    notificationCenter.addObserver(forName: Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
                                   object: nil,
                                   queue: nil,
                                   using: handleNowPlayingInfoDidChangeNotification)
    
    // Register for application playback state change notification
    notificationCenter.addObserver(forName: Notification.Name("kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification"),
                                   object: nil,
                                   queue: nil,
                                   using: handleNowPlayingApplicationPlaybackStateDidChange)
    
    let center = NSWorkspace.shared.notificationCenter
    
    // Register for the launch of an application notification
    center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                       object: nil,
                       queue: OperationQueue.main) { (notification: Notification) in
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            if app.bundleIdentifier == targetAppBundleIdentifier {
                // Register Now Playing notifications
                MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
                debugPrint("MediaRemote now playing notifications registered.")
            }
        }
    }
    
    // Register for the termination of an application notification
    center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                       object: nil,
                       queue: OperationQueue.main) { (notification: Notification) in
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            if app.bundleIdentifier == targetAppBundleIdentifier {
                // Unregister Now Playing notifications
                MRMediaRemoteUnregisterForNowPlayingNotifications(DispatchQueue.main)
                debugPrint("MediaRemote now playing notifications unregistered.")
            }
        }
    }
    
    // Check if the application is already running at startup
    if let targetApp = NSRunningApplication.runningApplications(withBundleIdentifier: targetAppBundleIdentifier).first {
        debugPrint("Application is running: \(targetApp.localizedName ?? "").")
        
        // Register Now Playing notifications
        MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
        debugPrint("MediaRemote now playing notifications registered.")
        
        // Check the current playback state at startup
        getPlaybackState { isPlaying in
            if isPlaying {
                // Handle the case when the application is already playing
            }
        }
    } else {
        debugPrint("Application is not running.")
    }
}


/**
 Toggles play/pause for the currently active media player.
 
 - Note: This function relies on `MRMediaRemoteGetNowPlayingInfo` and `MRMediaRemoteSendCommand` to interact with the media player.
 
 - Warning: This function assumes the availability of certain media player information. Make sure to handle potential errors and edge cases appropriately.
 
 - Important: This function uses the `getPlayerNameConfig` function to determine the expected player bundle identifier. Ensure that this function is correctly implemented.
 
 - Returns: None
 */
func togglePlayPause() {
    // Get now playing information using MRMediaRemoteGetNowPlayingInfo
    MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main, { information in
        
        // Deserialize protobuf data to extract bundle information
        let bundleInfo = Dynamic._MRNowPlayingClientProtobuf.initWithData(information["kMRMediaRemoteNowPlayingInfoClientPropertiesData"])
        
        // Check if the now playing information is empty
        if information.isEmpty {
            debugPrint("Now playing information is empty.")
            return
        }
        
        // Extract player name and bundle identifier
        let playerName = bundleInfo.displayName.asString ?? ""
        let playerBundleIdentifier = bundleInfo.bundleIdentifier.asString ?? ""
        debugPrint("playerName=\(playerName)")
        
        // Check if the detected player is the expected player
        if playerBundleIdentifier != getPlayerNameConfig() {
            debugPrint("Specified player not detected running: \(getPlayerNameConfig())")
            debugPrint("detected bundle \(playerBundleIdentifier) name \(playerName)")
            showAlert(title: "Error", message: "Specified player not detected running: \(getPlayerNameConfig())")
            return
        }
        
        // Send the toggle play/pause command using MRMediaRemoteSendCommand
        let result = MRMediaRemoteSendCommand(MRCommand.kMRTogglePlayPause.rawValue, nil)
        debugPrint("MRMediaRemoteSendCommand=\(result)")
        
        // Show a success Toast notification if the command was successful
        //        if result {
        //            showRegularToast("Toggle Play/Pause successful.")
        //        }
        if result {
            getPlaybackState { isPlaying in
                let message = isPlaying ? "Playback paused." : "Playback resumed."
                showRegularToast(message)
            }
        }
    })
}


/**
 Toggles the play for the next track.
 
 This function retrieves now playing information using MRMediaRemoteGetNowPlayingInfo,
 extracts bundle information, and sends a command to play the next track if the specified player is detected.
 */
func togglePlayNext() {
    // Get now playing information using MRMediaRemoteGetNowPlayingInfo
    MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main, { information in
        
        // Deserialize protobuf data to extract bundle information
        let bundleInfo = Dynamic._MRNowPlayingClientProtobuf.initWithData(information["kMRMediaRemoteNowPlayingInfoClientPropertiesData"])
        
        // Check if the now playing information is empty
        if information.isEmpty {
            debugPrint("Now playing information is empty.")
            return
        }
        
        // Extract player name and bundle identifier
        let playerName = bundleInfo.displayName.asString ?? ""
        let playerBundleIdentifier = bundleInfo.bundleIdentifier.asString ?? ""
        debugPrint("playerName=\(playerName)")
        
        // Check if the detected player is the expected player
        if playerBundleIdentifier != getPlayerNameConfig() {
            debugPrint("Specified player not detected running: \(getPlayerNameConfig())")
            debugPrint("detected: \(playerBundleIdentifier)")
            showAlert(title: "Error", message: "Specified player not detected running: \(getPlayerNameConfig())")
            return
        }
        
        // Send a command to play the next track
        let result = MRMediaRemoteSendCommand(MRCommand.kMRNextTrack.rawValue, nil)
        debugPrint("MRMediaRemoteSendCommand=\(result)")
        
        if result {
            showRegularToast("Next track playing.")
        }
    })
}


/**
 Retrieves information about the currently playing track.
 
 This function calls the Media Remote framework to get now playing information and
 extracts relevant details such as artist, title, album, duration, and artwork.
 The information is then passed to the provided completion handler.
 
 - Parameter completion: A closure that takes a dictionary containing track information as its argument.
 */
func getTrackInformation(completion: @escaping ([String: Any]) -> Void) {
    // Initialize a dictionary to store now playing information
    var nowPlayingInfo: [String: Any] = [:]
    
    // Call the Media Remote framework to get now playing information
    MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { information in
        
        // Check if the information is empty
        if information.isEmpty {
            // Call the completion handler with an empty dictionary
            completion(nowPlayingInfo)
            return
        }
        
        // Extract information from the result
        nowPlayingInfo["Artist"] = information["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        nowPlayingInfo["Title"] = information["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        nowPlayingInfo["Album"] = information["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        nowPlayingInfo["Duration"] = secondsToFormattedString(information["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0.0)
        
        // Extract and convert artwork data to NSImage
        let artworkData = information["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        nowPlayingInfo["Artwork"] = artworkData.flatMap { NSImage(data: $0) }
        
        // Call the completion handler with the updated dictionary
        completion(nowPlayingInfo)
    }
}
