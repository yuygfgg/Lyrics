//
//  SearchLyrics.swift
//  Lyrics
//
//  Created by Fang Liangchen on 2023/12/26.
//

import SwiftUI
import Foundation
import Cocoa

/// Model representing a search result item.
struct SearchResultItem: Identifiable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var duration: String
}

/// Model representing the result of a search.
struct SearchResult: Decodable {
    var result: Result
}

/// Model representing the result of a search.
struct Result: Decodable {
    var songs: [Song]
}

/// Model representing a song.
struct Song: Decodable {
    var id: Int
    var name: String
    var artists: [Artist]
    var album: Album
    var duration: Int
}

/// Model representing an artist.
struct Artist: Decodable {
    var name: String
}

/// Model representing an album.
struct Album: Decodable {
    var name: String
}

/// Model representing a single lyric item.
struct LyricItem {
    let timestamp: TimeInterval
    let content: String
}


/// SwiftUI view representing a sub-window.
struct LyricsSearchView: View {
    
    var onClose: (() -> Void)
    @State var searchText: String = ""
    @State var searchResults: [SearchResultItem]  = [] // Results to be displayed.
    @State var selectedItemId: String? // Selected item ID.
    
    var body: some View {
        VStack {
            HStack {
                // Text field for entering search keyword.
                TextField("Enter search keyword", text: $searchText, onCommit: {searchButtonTapped()})
                // Button to initiate the search.
                Button("Search") {
                    // Call the searchButtonTapped method to handle search logic.
                    searchButtonTapped()
                }
            }
            // Table displaying search results.
            Table(searchResults, selection: $selectedItemId) {
                TableColumn("Title", value: \.title)
                TableColumn("Artist", value: \.artist)
                TableColumn("Album", value: \.album)
                TableColumn("Duration", value: \.duration)
            }
            // Context menu for the search results.
            .contextMenu(forSelectionType: SearchResultItem.ID.self
            ) { items in
            } primaryAction: { items in
                // Action when a row is double-clicked.
                if let selectedItem = searchResults.first(where: { $0.id == selectedItemId }) {
                    let id = selectedItem.id
                    debugPrint("Preparing to get lyrics for song ID " + id)
                    
                    // Extract the relevant information from the selected item.
                    let title = selectedItem.title
                    let artist = selectedItem.artist
                    let album = selectedItem.album
                    
                    // Download lyrics and display an alert.
                    download(id: id, artist: artist, title: title, album: album) { combinedLyrics in
                        if let combinedLyrics = combinedLyrics {
                            // Ensure that UI-related code is executed on the main thread
                            DispatchQueue.main.async {
                                showTextAreaAlert(title: "Save Lyrics", message: "Are you sure you want to save the lyrics?", defaultValue: combinedLyrics, firstButtonText: "Download") { text in
                                    saveLyricsToFile(lyrics: text, artist: artist, title: title)
                                    // Lyrics load immediately after saving.
                                    
                                    // Check playback state
                                    getPlaybackState { isPlaying in
                                        if isPlaying {
                                            // Stop displaying lyrics
                                            stopLyrics()
                                            
                                            // Start displaying lyrics
                                            startLyrics()
            
                                        }
                                    }
                                    
                    
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                showAlert(title: "Save Lyrics", message: "Failed to fetch lyrics.")
                            }
                        }
                    }
                }
            }
            // Add a border to the table.
            .border(Color.gray, width: 1)
        }
        // Add padding to the entire view.
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow {
                if window.title == "Search Lyrics" {
                    print("Subwindow became key.")
                    if let currentTrack = currentTrack, !currentTrack.isEmpty {
                        
                        if searchText != currentTrack {
                            searchText = currentTrack
                            searchButtonTapped()
                        }
                        
                    }
                }
            }
        }
        
        // Set the initial value of searchText to currentTrack when the view appears.
        .onAppear() {
            // Check if currentTrack is not empty before setting the searchText and triggering the search logic.
            if let currentTrack = currentTrack, !currentTrack.isEmpty {
                searchText = currentTrack
                // Simulate a button tap to trigger the search logic.
                searchButtonTapped()
            }
            
        }
        // Perform actions when the view disappears.
        .onDisappear {
            onClose()
            debugPrint("Subwindow closed")
        }
        
    }
    func durationStringToSeconds(_ duration: String) -> TimeInterval? {
        let components = duration.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return nil
        }
        return TimeInterval(minutes * 60 + seconds)
    }
    
    
    
    /**
     Handles the search button tap event.
     
     - Note: This function performs a series of checks and actions when the search button is tapped.
     It validates the entered keyword, displays an alert if needed, and calls the `searchSong` function to perform the actual search.
     
     - Returns: None
     */
    private func searchButtonTapped() {
        // 检查搜索关键词是否为空
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            debugPrint("Search Lyrics: Keyword input is empty.")
            return
        }

        // 先获取当前播放歌曲的时长
        getCurrentSongDuration { currentSongDuration in
            guard let currentSongDuration = currentSongDuration else {
                DispatchQueue.main.async {
                    debugPrint("Error: Failed to get current song duration.")
                }
                return
            }

            // 然后进行歌曲搜索
        searchSong(keyword: self.searchText) { result, error in
            if let error = error {
                debugPrint("Error during song search: \(error)")
                return
            }
            if let songs = result?.songs {
                DispatchQueue.main.async {
                    // 过滤掉与当前播放歌曲时长差异大于3秒的歌曲
                    debugPrint("Current Song Duration: \(currentSongDuration)")
                    for song in songs {
                        debugPrint("Song Duration: \(song.duration)")
                    }
                    debugPrint("filter!!")
                    let filteredSongs = songs.filter { abs(Double($0.duration)/1000 - currentSongDuration) >= 0 }
                            self.searchResults = filteredSongs.map {
                                SearchResultItem(id: "\($0.id)", title: $0.name, artist: $0.artists.first?.name ?? "Unknown Artist", album: $0.album.name, duration: millisecondsToFormattedString(TimeInterval($0.duration)))
                        }
                    }
                }
            }
        }
    }
    
}


/// Function to search for a song based on a keyword.
///
/// - Parameters:
///   - keyword: The keyword to search for.
///   - completion: A closure to be executed upon completion of the search, providing either a `Result` or an `Error`.
func searchSong(keyword: String, completion: @escaping (Result?, Error?) -> Void) {
    debugPrint("searching...")
    // Ensure the keyword is properly encoded for a URL.
    guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        print("Error: Unable to encode keyword")
        return
    }
    
    // Construct the API URL for the search.
    let apiUrl = "https://music.163.com/api/search/get?s=\(encodedKeyword)&type=1&limit=50"
    
    // Create a URL object from the API URL string.
    guard let url = URL(string: apiUrl) else {
        print("Invalid URL")
        return
    }
    
    // Perform a data task to fetch the search results.
    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        // Handle any error that occurred during the task.
        if let error = error {
            completion(nil, error)
            return
        }
        
        // Ensure that data was received.
        guard let data = data else {
            print("No data received")
            return
        }
        
        // Attempt to decode the received JSON data.
        do {
            let decoder = JSONDecoder()
            let searchResult = try decoder.decode(SearchResult.self, from: data)
            completion(searchResult.result, nil)
        } catch {
            print("Error decoding JSON: \(error)")
            completion(nil, error)
        }
    }
    // Start the data task.
    task.resume()
}


/// Downloads lyrics for a given song ID.
/// - Parameters:
///   - id: The ID of the song for which lyrics are to be downloaded.
///   - completion: A closure to be called with the downloaded lyrics or `nil` if an error occurs.
func download(id: String, artist: String, title: String, album: String, completion: @escaping (String?) -> Void) {
    let urlString = "https://music.163.com/api/song/lyric"
    let parameters = ["tv": "-1", "lv": "-1", "kv": "-1", "id": id]
    
    // Construct the URL for the lyric API with the given parameters.
    var urlComponents = URLComponents(string: urlString)
    urlComponents?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    guard let url = urlComponents?.url else {
        debugPrint("Invalid URL")
        completion(nil)
        return
    }
    
    // Perform a data task to download lyric data from the API.
    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        // Handle any error that occurred during the data task.
        if let error = error {
            debugPrint("Error: \(error)")
            completion(nil)
            return
        }
        
        do {
            // Ensure that data was received.
            guard let data = data else {
                debugPrint("No data received")
                completion(nil)
                return
            }
            
            // Attempt to parse the received JSON data.
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            // Extract lyric data from the JSON response.
            if let lrc = json?["lrc"] as? [String: Any], let lrcText = lrc["lyric"] as? String,
               let tlyric = json?["tlyric"] as? [String: Any], let tlyricText = tlyric["lyric"] as? String {
                
                // Parse lyric text into LyricItem objects.
                let lrcItems = parseLyric(lrcText)
                let tlyricItems = parseLyric(tlyricText)
                // Combine and sort lyric items based on timestamp.
                let combinedItems = (lrcItems + tlyricItems).sorted { $0.timestamp < $1.timestamp }
                
                // Create a set to keep track of seen timestamps with empty content.
                var seenEmptyTimestamps = Set<TimeInterval>()
                
                // Filter and process lyric items.
                let processedItems = combinedItems.filter { item in
                    // Check if the content is empty or has been seen before.
                    let isContentEmpty = item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let isTimestampSeen = seenEmptyTimestamps.contains(item.timestamp)
                    
                    // Update the set and keep the item if the content is not empty or it's the first empty content for this timestamp.
                    if !isContentEmpty || !isTimestampSeen {
                        seenEmptyTimestamps.insert(item.timestamp)
                        return true
                    } else {
                        return false
                    }
                }
                
                // Generate a string representation of the processed lyric items.
                var combinedLyrics = processedItems.map { "[\(timeIntervalToLyricsTimestamp($0.timestamp))]\($0.content.trimmingCharacters(in: .whitespacesAndNewlines))" }.joined(separator: "\n")
                
                var idTags = "[ar:\(artist)]\n[ti:\(title)]\n[al:\(album)]\n"
                
                // Check if the lyricUser and transUser information is available.
                if let lyricUser = json?["lyricUser"] as? [String: Any], let lyricUserNickname = lyricUser["nickname"] as? String {
                    idTags += "[by:\(lyricUserNickname)]\n"
                }
                
                if  let transUser = json?["transUser"] as? [String: Any], let transUserNickname = transUser["nickname"] as? String {
                    idTags += "[trans:\(transUserNickname)]\n"
                }
                
                // Insert ID tags at the beginning of combinedLyrics.
                combinedLyrics = idTags + combinedLyrics
                
                // Return the result through the completion closure.
                completion(combinedLyrics)
            } else {
                debugPrint("Failed to parse lyrics from JSON")
                completion(nil)
            }
        } catch {
            debugPrint("Error parsing JSON: \(error)")
            completion(nil)
        }
    }
    // Start the data task.
    task.resume()
}


/// Parses the lyric text and returns an array of lyric items.
/// - Parameter lyricText: The raw lyric text to be parsed.
/// - Returns: An array of `LyricItem` objects.
//func parseLyric(_ lyricText: String) -> [LyricItem] {
//    var lyricItems = [LyricItem]()
//
//    
//    // Split the lyric text into lines.
//    let lines = lyricText.components(separatedBy: "\n")
//    
//    
//    
//    // Iterate through each line to extract timestamp and content.
//    for line in lines {
//        
//        debugPrint(line)
//        // Use regular expression to extract timestamp and lyric content.
//        if let match = line.range(of: "\\[(\\d+:\\d+\\.\\d+)\\]", options: .regularExpression) {
//            let timestampString = String(line[match])
//            let content = line.replacingOccurrences(of: "\\[(\\d+:\\d+\\.\\d+)\\]", with: "", options: .regularExpression)
//            
//            // Convert the timestamp to a time interval.
//            if let timestamp = lyricsTimestampToTimeInterval(timestampString) {
//                let lyricItem = LyricItem(timestamp: timestamp, content: content)
//                lyricItems.append(lyricItem)
//            }
//        }
//    }
//    
//    return lyricItems
//}
func parseLyric(_ lyricText: String) -> [LyricItem] {
    var lyricItems = [LyricItem]()

    // Split the lyric text into lines.
    let lines = lyricText.components(separatedBy: "\n")

    // Iterate through each line to extract timestamp and content.
    for line in lines {
        // Use regular expression to extract timestamp and lyric content.
        if let match = line.range(of: "\\[(\\d+:\\d+(\\.\\d+)?|\\d+:\\d+:\\d+)\\]", options: .regularExpression) {
            var timestampString = String(line[match])
            var content = line.replacingOccurrences(of: "\\[(\\d+:\\d+(\\.\\d+)?|\\d+:\\d+:\\d+)\\]", with: "", options: .regularExpression)

            // Check if the timestamp has the format [数字:数字:数字].
            if timestampString.contains(":") && timestampString.filter({$0 == ":"}).count == 2 {
                // Find the last ":" index.
                if let lastColonIndex = timestampString.lastIndex(of: ":") {
                    // Replace the last ":" with ".".
                    timestampString.replaceSubrange(lastColonIndex...lastColonIndex, with: ".")
                }
            }

            // Convert the timestamp to a time interval.
            if let timestamp = lyricsTimestampToTimeInterval(timestampString) {
                let lyricItem = LyricItem(timestamp: timestamp, content: content)
                lyricItems.append(lyricItem)
            }
        }
    }

    return lyricItems
}

