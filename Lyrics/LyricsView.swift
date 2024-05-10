//
//  LyricsView.swift
//  Lyrics
//
//  Created by Fang Liangchen on 2023/12/28.
//

import Foundation
import SwiftUI
import AlertToast


/// View model for managing lyrics data.
class LyricsViewModel: ObservableObject {
    
    /// Shared instance of LyricsViewModel.
    static let shared = LyricsViewModel()
    
    /// Published property holding the array of LyricInfo representing the lyrics.
    @Published var lyrics: [LyricInfo] = []
    
    /// Published property holding the current index of the lyrics.
    @Published var currentIndex: Int = 0
    
}

/// The main view model instance for managing lyrics.
var viewModel = LyricsViewModel.shared

/// The start time for tracking the playback time.
var startTime: TimeInterval = 0

/// A boolean indicating whether the lyrics display is stopped.
var isStopped: Bool = true


/// SwiftUI view representing the lyrics interface.
struct LyricsView: View {
    
    @ObservedObject private var lyricViewModel: LyricsViewModel = LyricsViewModel.shared
    @ObservedObject  var uiPreferences: UIPreferences = UIPreferences.shared
    
    @State private var isCopiedAlertPresented: Bool = false
    @State private var isHovered = false
    
    var body: some View {

        ZStack {
            GeometryReader { geometry in
                if let image = uiPreferences.coverImage {
                    Image(nsImage: image)
                        .resizable() // Make the image resizable
                        .scaledToFill() // Scale the image to fill the available space
                        .aspectRatio(contentMode: .fill) // Maintain the aspect ratio while filling the container
                        .frame(width: geometry.size.width, height:geometry.size.height + geometry.safeAreaInsets.top, alignment: .center)  // Set the frame size and alignment
                        .clipped() // Clip the image to fit within the frame
                        .ignoresSafeArea() // Ignore safe areas, allowing the image to extend beyond them
                        .blur(radius: 5) // Apply a blur effect with a radius of 5
                        .opacity(0.6) // Set the opacity of the image to 60%
                        .overlay(Color.black.opacity(0.5)) // Overlay the image with a semi-transparent black layer
                }
            }
            
            
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 10) {
                        ForEach(viewModel.lyrics) { lyric in
                            Text(lyric.text)
                                .font(.system(size: 14)) // Set the font size
                                .foregroundColor(lyric.isCurrent ? .blue : .white) // Set text color based on whether it's the current lyric
                                .multilineTextAlignment(.center) // Center-align the text
                                .padding(.vertical, lyric.isTranslation ? -30 : 30) // Add vertical padding based on whether it's a translation
                                .padding(.horizontal, 10) // Add horizontal padding
                                .frame(maxWidth: .infinity, alignment: .center) // Expand the frame to the maximum width
                                .id(lyric.id)  // Set an identifier for the lyric
                                .onTapGesture {
                                    copyToClipboard(lyric.text)
                                    isCopiedAlertPresented = true
                                }
                        }
                    }
                    .onChange(of: lyricViewModel.currentIndex) { [oldValue = lyricViewModel.currentIndex] newValue in
                        
                        debugPrint("oldValue=\(oldValue), newValue=\(newValue)")
                        
                        // Scroll to the current lyric's position
                        withAnimation() {
                            
                            // Set all lyrics to not current
                            viewModel.lyrics.indices.forEach { index in
                                viewModel.lyrics[index].isCurrent = false
                            }
                            
                            // Check if the old value is within the lyrics array bounds
                            if (oldValue > 0 && oldValue < viewModel.lyrics.count) {
                                
                                // Set the old value as the current lyric and scroll to it
                                viewModel.lyrics[oldValue].isCurrent = true
                                proxy.scrollTo(oldValue, anchor: .center)
                            }
                            
                        }
                    }
                }
            }
            if isHovered && uiPreferences.isPlaybackProgressVisible && uiPreferences.playbackProgress != 0 {
                // Display the playback progress text
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(secondsToFormattedString(uiPreferences.playbackProgress))
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.8))
                            .padding(6)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(6)
                            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                    }
                }
                .padding()
            }
        }

        .onAppear {
            startTimer()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .alert(isPresented: $isCopiedAlertPresented) {
            Alert(
                title: Text("Lyrics Copied"),
                message: Text("Lyrics text has been copied to the clipboard."),
                dismissButton: .default(Text("OK"))
            )
        }
        .toast(isPresenting: $uiPreferences.showToast){
            AlertToast(type: uiPreferences.toastType, title: uiPreferences.toastText)
        }
        .contextMenu {
            Button("Search Lyrics") {
                handleSearchLyrics()
            }
            
            Toggle("Toggle Sticky", isOn: Binding<Bool>(
                get: {
                    return uiPreferences.isWindowSticky
                },
                set: { isEnabled in
                    handleToggleSticky(isEnabled: isEnabled)
                }
            ))
            
            
            Menu("Player") {
                Button("Open Player") {
                    openApp(withBundleIdentifier: getPlayerNameConfig())
                }
                
                Button("Play Next Track") {
                    togglePlayNext()
                }
                
                Button("View Track Information") {
                    viewTrackInformation()
                }
            }
            
            Menu("Lyrics File") {
                
                Button("Open Lyrics File") {
                    openLyricsFile()
                }
                
                Button("Show Lyrics File In Finder") {
                    showLyricsFileInFinder()
                }
            }
            
            Divider()
            
            Menu("Calibration") {
                
                Button("Recalibration") {
                    handleRecalibration()
                }
                Button("1 Second Faster") {
                    handle1SecondFaster()
                }
                Button("1 Second Slower") {
                    handle1SecondSlower()
                }
                Button("Manual Calibration") {
                    handleManualCalibration()
                }
                
                
            }
            
            Divider()
            
            
        }
        .onDisappear() {
            debugPrint("Main window closed.")
            NSApplication.shared.windows.forEach { window in
                window.close()
            }
        }
        .gesture(TapGesture(count: 2).onEnded {
            debugPrint("Double clicked")
            
            togglePlayPause()
        })
    }
    
    
    /// Start a timer to update lyrics every second.
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isStopped {
                updateLyrics()
            }
        }
    }
    
    
    /// Update the lyrics based on the current playback time.
    private func updateLyrics() {
        // Check if lyrics display is stopped
        guard !isStopped else {
            return
        }
        
        // Check if the current lyric index is within the array bounds
        guard lyricViewModel.currentIndex >= 0 && lyricViewModel.currentIndex < viewModel.lyrics.count else {
            print("Playback is over.")
            stopLyrics()
            return
        }
        
        // Calculate the current playback progress
        let currentPlaybackTime = Date().timeIntervalSinceReferenceDate - startTime
        
        // Update the playback progress
        uiPreferences.playbackProgress = currentPlaybackTime
        
        // Get the current lyric
        let currentLyric = viewModel.lyrics[lyricViewModel.currentIndex]
        
        // Check if it's time to display the current lyric
        if currentPlaybackTime >= currentLyric.playbackTime {
            
            debugPrint("currentPlayBackTime=\(currentPlaybackTime), currentLyricPlaybackTime=\(currentLyric.playbackTime), currentIndex=\(lyricViewModel.currentIndex), currentLyricText=\(currentLyric.text)")
            
            if !currentLyric.isTranslation{
                viewModel.updateStatusBar(with: currentLyric.text)
            }
            
            // Increase the lyric index
            lyricViewModel.currentIndex += 1
            
            // Check if there is a next lyric
            if lyricViewModel.currentIndex < viewModel.lyrics.count {
                let nextLyric = viewModel.lyrics[lyricViewModel.currentIndex]
                
                // Skip translation lyrics
                if nextLyric.isTranslation {
                    updateLyrics()
                    return
                }
                
                // Calculate the delay time
                let delay = nextLyric.playbackTime - currentLyric.playbackTime
                
                // Use asynchronous delay to continue displaying lyrics
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Update the next lyric
                    updateLyrics()
                }
            }
        }
    }}


func startLyrics() {
    getNowPlayingInfo { nowPlayingInfo in
        guard !nowPlayingInfo.isEmpty else {
            debugPrint("Now playing information is empty.")
            return
        }
        
        guard let playbackTime = nowPlayingInfo["ElapsedTime"] as? TimeInterval,
              let artist = nowPlayingInfo["Artist"] as? String,
              let title = nowPlayingInfo["Title"] as? String else {
            debugPrint("Failed to get essential playback information.")
            return
        }

        // 先获取当前播放歌曲的时长
        getCurrentSongDuration { currentSongDuration in
            guard let currentSongDuration = currentSongDuration else {
                debugPrint("Failed to get current song duration.")
                return
            }

            var keyword = "\(title)"  // 默认关键词
            var shouldFilter = true   // 默认应用过滤

            // 当歌曲时长大于等于600秒时，修改搜索关键词并且不过滤搜索结果
            if currentSongDuration >= 600 {
                keyword = "\(artist) - \(title)"
                shouldFilter = false
            }

            let lrcPath = getLyricsPath(artist: artist, title: title)

            if let lrcContent = try? String(contentsOfFile: lrcPath) {
                debugPrint("Lyrics file loaded: \(lrcPath)")
                isStopped = false
                let parser = LyricsParser(lrcContent: lrcContent)
                viewModel.lyrics = parser.getLyrics()
                updatePlaybackTime(playbackTime: playbackTime)
            } else {
                debugPrint("Failed to read LRC file, attempting to fetch lyrics online. Search for \(keyword)")
                // 搜索歌曲
                searchSong(keyword: keyword) { result, error in
                    guard let result = result, error == nil else {
                        debugPrint("No suitable results found or error occurred: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }

                    let songs: [Song]
                    if shouldFilter {
                        // 过滤掉与当前播放歌曲时长差异大于3秒的歌曲
                        songs = result.songs.filter { abs(Double($0.duration) / 1000 - currentSongDuration) <= 3 }
                    } else {
                        songs = result.songs  // 不应用过滤
                    }

                    // 尝试从过滤后的歌曲中下载歌词
                    attemptToDownloadLyricsFromSongs(songs: songs, index: 0, playbackTime: playbackTime, artist: artist, title: title)
                }
            }
        }
    }
}

private func attemptToDownloadLyricsFromSongs(songs: [Song], index: Int, playbackTime: TimeInterval, artist: String, title: String) {
    if index >= songs.count {
        debugPrint("Attempted all songs but failed to download lyrics.")
        // 所有下载尝试失败后，显示默认歌词
        initializeLyrics(withDefault: [
            LyricInfo(id: 0, text: "\(artist) - \(title)", isCurrent: true, playbackTime: 0, isTranslation: false)
        ])
        return
    }

    let song = songs[index]
    debugPrint("\(song.id) trying download \(song.name) by \(song.artists) duration \(song.duration)")
    download(id: String(song.id), artist: song.artists.first?.name ?? "", title: song.name, album: song.album.name) { lyricsContent in
        guard let lyricsContent = lyricsContent else {
            debugPrint("Failed to download lyrics for song \(song.name). Trying next song.")
            attemptToDownloadLyricsFromSongs(songs: songs, index: index + 1, playbackTime: playbackTime, artist: artist, title: title)
            return
        }

        DispatchQueue.main.async {
            isStopped = false
            let parser = LyricsParser(lrcContent: lyricsContent)
            viewModel.lyrics = parser.getLyrics()
            updatePlaybackTime(playbackTime: playbackTime)
        }
    }
}

/// Stops displaying lyrics for the currently playing track.
func stopLyrics() {
    isStopped = true
    UIPreferences.shared.playbackProgress = 0
}


/// Finds the lyric index corresponding to the specified start time.
///
/// - Parameter startTime: The playback start time.
/// - Returns: The index of the lyric or -1 if not found.
private func findStartingLyricIndex(_ startTime: TimeInterval) -> Int {
    for (index, lyric) in viewModel.lyrics.enumerated() {
        if lyric.playbackTime >= startTime {
            return index
        }
    }
    return -1
}


/// Updates the playback time based on the specified playback time.
///
/// - Parameter playbackTime: The new playback time.
func updatePlaybackTime(playbackTime: TimeInterval) {
    // Set the start time based on the playback time
    startTime = Date.timeIntervalSinceReferenceDate - (playbackTime + getGlobalOffsetConfig())
    // Reset the lyric index to the beginning
    LyricsViewModel.shared.currentIndex = 0
    // Find and set the starting lyric index
    LyricsViewModel.shared.currentIndex = findStartingLyricIndex(playbackTime)
}


/// Initializes the lyrics with the provided default set.
///
/// - Parameters:
///   - lyrics: The default set of lyrics to initialize.
func initializeLyrics(withDefault lyrics: [LyricInfo]) {
    // Set the start time to the current reference date
    startTime = Date().timeIntervalSinceReferenceDate
    // Set the lyrics to the provided default set
    viewModel.lyrics = lyrics
}


/**
 Opens the lyrics file corresponding to the current track.
 
 If there is no current track, it shows an error alert. If the lyrics file exists, it opens the file using NSWorkspace;
 otherwise, it shows an error alert indicating that the lyrics were not found.
 */
private func openLyricsFile() {
    // Check if there is a current track
    guard let track = currentTrack else {
        // Activate the application and show an error alert if no tracks are currently playing
        NSApp.activate(ignoringOtherApps: true)
        showAlert(title: "Error", message: "There are no tracks currently playing.")
        return
    }
    
    // Create a file URL based on the lyrics path for the current track
    let fileURL = URL(fileURLWithPath: getCurrentTrackLyricsPath())
    
    // Check if the lyrics file exists
    if FileManager.default.fileExists(atPath: fileURL.path) {
        // Open the lyrics file using NSWorkspace
        NSWorkspace.shared.open(fileURL)
    } else {
        // Activate the application and show an error alert if the lyrics file is not found
        NSApp.activate(ignoringOtherApps: true)
        showAlert(title: "Error", message: "Lyrics not found.")
    }
}


/**
 Shows the lyrics file corresponding to the current track in the Finder.
 
 If there is no current track, it shows an error alert. If the lyrics file exists,
 it opens the Finder and selects the file; otherwise, it shows an error alert indicating
 that the lyrics were not found.
 */
private func showLyricsFileInFinder() {
    // Check if there is a current track
    guard let track = currentTrack else {
        // Activate the application and show an error alert if no tracks are currently playing
        NSApp.activate(ignoringOtherApps: true)
        showAlert(title: "Error", message: "There are no tracks currently playing.")
        return
    }
    
    // Create a file URL based on the lyrics path for the current track
    let fileURL = URL(fileURLWithPath: getCurrentTrackLyricsPath())
    
    // Check if the lyrics file exists
    if FileManager.default.fileExists(atPath: fileURL.path) {
        // Open the Finder and select the lyrics file
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    } else {
        // Activate the application and show an error alert if the lyrics file is not found
        NSApp.activate(ignoringOtherApps: true)
        showAlert(title: "Error", message: "Lyrics not found.")
    }
}


/**
 Displays track information including artist, title, album, duration, and artwork.
 
 Activates the application and retrieves track information using `getTrackInformation`.
 Shows an error alert if there are no tracks currently playing; otherwise, displays a detailed alert
 with the retrieved track information and artwork, if available.
 */
private func viewTrackInformation() {
    // Activate the application
    NSApp.activate(ignoringOtherApps: true)
    
    // Retrieve track information
    getTrackInformation() { info in
        // Check if the track information is empty
        if info.isEmpty {
            // Show an error alert if there are no tracks currently playing
            showAlert(title: "Error", message: "There are no tracks currently playing.")
        } else {
            // Display a detailed alert with track information and artwork
            showImageAlert(
                title: "Track Information",
                message:
                        """
                        Artist: \(info["Artist"] ?? "Unknown Artist")
                        Title: \(info["Title"] ?? "Unknown Title")
                        Album: \(info["Album"] ?? "Unknown Album")
                        Duration: \(info["Duration"] ?? "Unknown Duration")
                        """,
                image: info["Artwork"] as? NSImage
            )
        }
    }
}


