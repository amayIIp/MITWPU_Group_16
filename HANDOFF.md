# Handoff

Done:
- Reorganized the app into MVVM-first top-level folders: `Model/`, `View/`, and `ViewModel/`, with feature folders inside each.
- Removed unused linked products/packages from the Xcode project: `GoogleSignInSwift`, `RiveRuntime`, `SpeakerKit`, and `TTSKit`.
- Added `Stuttering AppTests` with view smoke tests for storyboards, nibs, cells, and programmatic views.
- Updated the README architecture section.

Verified:
- `project.pbxproj` parses with `plutil`.
- Shared scheme XML parses with `xmllint`.
- `xcodebuild -list` succeeds and shows `Stuttering App` plus `Stuttering AppTests`.
- First test run built and executed 4 of 5 tests successfully; the failing cell test was fixed afterward.

Still to do:
- Re-run the full test suite. The final rerun built successfully but the simulator failed to launch `com.spasht.app` because Xcode could not resolve `simctl` under the current developer-dir environment.
- Use this command when back:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project "Stuttering App.xcodeproj" -scheme "Stuttering App" -destination 'platform=iOS Simulator,name=iPhone 17'`
