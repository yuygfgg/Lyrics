# Lyrics App for macOS

A macOS app that presents a synchronized scrolling lyrics panel based on the currently playing track in the system.

## Features

- Display synchronized scrolling lyrics corresponding to system now playing tracks.

- Display lyrics in status bar.

- Automatically loads the LRC file corresponding to the currently playing track and present the lyrics at the correct timeline based on playback progress.

- Monitor events such as pausing, resuming, and track switching, as well as startup and exit events for the specified player.

- Lyrics panel interface supports displaying album art and playback progress of the currently playing track.

- Download missing lyrics automatically.

- Allows online search, preview and download of lyrics, currently supports NetEase Cloud Music.

- Robust support for both single-line lyrics and two-line translated lyrics.

- Allows users to adjust lyrics progress for accurate synchronization with music playback.

## How to Use

1. On the first launch, configure your player's bundle identifier and lyrics storage directory in the "Settings" menu. Restart the application after completing the configuration.

2. After relaunching the app, start playing music in your player, and the lyrics will automatically load and appear in the window.

3. Lyrics are matched with the playing track by naming LRC files as "artist - title.lrc" within the lyrics folder. Use the "Search Lyrics" menu for online searches. It will automatically search for the lyrics of the current track from NetEase Cloud Music. Double-click on the lyrics you wish to use to preview them, then click the download button to save the lyrics to the configured folder.

4. Due to the use of macOS's private APIs instead of direct player association, lyrics progress may be inaccurate in the first few seconds after starting playback. We will recalibrate the progress after 3 seconds of playback by default. If it remains inaccurate, please manually calibrate it using the "Playback" menu.

5. Shortcut keys:
- `Control + L`: Activate window
- `Command + S`: Open the lyrics search window
- `Command + +`: Fast forward the lyrics by one second.
- `Command + -`: Rewind lyrics by one second.


## Build and Run

To build and run the application:

1. Clone the repository to your local machine.

2. Open the Xcode project file.

3. Build and run the project using Xcode.

4. Enjoy the app.

Feel free to contribute, report issues, or suggest enhancements to improve this app!

## Screenshot

One-Line Lyrics:

![SCR-20231227-lhjm](https://github.com/flc0105/Lyrics/assets/101919965/83743cbd-7d00-4385-aaf5-52c541989427)

Two-Line Lyrics:

![SCR-20231227-lfsm](https://github.com/flc0105/Lyrics/assets/101919965/2810d0da-3093-4126-9d0f-97b7b8e8ddc8)

Search Lyrics Window:

![SCR-20231227-lgdb](https://github.com/flc0105/Lyrics/assets/101919965/e3a91873-f8ef-40f2-ab53-8d88556ed76b)
