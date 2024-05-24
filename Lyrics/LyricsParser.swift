//
//  LRCParser.swift
//  Lyrics
//
//  Created by Fang Liangchen on 2023/12/28.
//

import Foundation


/// LyricInfo structure representing information for a single line of lyrics.
struct LyricInfo: Identifiable {
    /// Unique identifier for the lyric line.
    let id: Int
    /// The text of the lyric line.
    let text: String
    /// A boolean indicating whether the lyric line is currently being played.
    var isCurrent: Bool
    /// The playback time associated with the lyric line.
    var playbackTime: TimeInterval
    /// A boolean indicating whether the lyric is a translation.
    var isTranslation: Bool
}


/// Lyrics parser for handling LRC (Lyric) files.
class LyricsParser {
    var lyrics: [LyricInfo] = []
    
    /// Initializes the parser with the content of an LRC file.
    /// - Parameter lrcContent: Content of the LRC file.
    init(lrcContent: String) {
        parseLRCContent(lrcContent)
    }
    
    /// Parses the content of an LRC file.
    /// - Parameter content: Content of the LRC file as a string.
    func parseLRCContent(_ content: String) {
        debugPrint("called lyrics parser!!!")
        debugPrint("raw content:!!\(content)raw end!")
        // Replace CRLF with LF
        let unifiedContent = content.replacingOccurrences(of: "\r\n", with: "\n")
        
        // Split the content into lines
        let lines = unifiedContent.components(separatedBy: "\n")
        
        // Use regular expression to match timestamps
        let regex = try! NSRegularExpression(pattern: "\\[([0-9]+:[0-9]+.[0-9]+)\\]", options: [])
        
        for line in lines {
            // Find matches for timestamps in each line
            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count))
            if let match = matches.first {
                // Extract the time string
                let timeString = (line as NSString).substring(with: match.range(at: 1))
                // Split the time string into minutes and seconds
                let timeComponents = timeString.components(separatedBy: ":")
                if let minutes = Double(timeComponents[0]), let seconds = Double(timeComponents[1]) {
                    // Calculate the timestamp
                    let timestamp = minutes * 60 + seconds
                    // Extract the lyric text
                    let lyricText = line.replacingOccurrences(of: "\\[([0-9]+:[0-9]+.[0-9]+)\\]", with: "", options: .regularExpression, range: nil)
                    
//                    // Create a LyricInfo instance and add it to the array
//                    if let lastTimestamp = lyrics.last?.playbackTime, timestamp == lastTimestamp {
//                        lyrics.append(LyricInfo(id: lyrics.count, text: lyricText, isCurrent: false, playbackTime: timestamp, isTranslation: true))
//                    } else {
//                        lyrics.append(LyricInfo(id: lyrics.count, text: lyricText, isCurrent: false, playbackTime: timestamp, isTranslation: false))
//                    }
//                    
                    // Create a LyricInfo instance and add it to the array
                    
                    
                    // 如果这行歌词的时间戳和上一行一样，并且上一行不为空则是翻译歌词
                    if let lastTimestamp = lyrics.last?.playbackTime, timestamp == lastTimestamp {
        
                        
                        if let lastLyricText = lyrics.last?.text, !lastLyricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            lyrics.append(LyricInfo(id: lyrics.count, text: lyricText, isCurrent: false, playbackTime: timestamp, isTranslation: true))
                        } else {
                            lyrics.append(LyricInfo(id: lyrics.count, text: lyricText, isCurrent: false, playbackTime: timestamp, isTranslation: false))
                        }

                        
                    } else {
                        lyrics.append(LyricInfo(id: lyrics.count, text: lyricText, isCurrent: false, playbackTime: timestamp, isTranslation: false))
                    }
                    
                }
            }
        }
        
        // Sort the lyrics array based on timestamps
        lyrics.sort { $0.playbackTime < $1.playbackTime }
        debugPrint("lyrics after!! \(lyrics) lyrics after end!")
    }
    
    /// Gets the parsed lyrics as an array of LyricInfo.
    /// - Returns: An array of LyricInfo instances representing the lyrics.
    func getLyrics() -> [LyricInfo] {
        return lyrics
    }
}


