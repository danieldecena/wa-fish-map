# WAFishMap — attach Xcode project on the Mac

The Cloud Agent cannot create or compile `.xcodeproj` files. All Swift sources
are already in this repo; you only need an empty Xcode shell.

## Steps

1. Open Xcode → File → New → Project → iOS → App
2. Product Name: `WAFishMap`
3. Organization Identifier: `com.danieldecena`
4. Bundle Identifier: `com.danieldecena.WAFishMap`
5. Interface: SwiftUI, Language: Swift, Storage: None
6. Testing: Swift Testing (include tests, no UI tests)
7. Save into **this directory** (`~/developer/wa-fish-map`)

If Xcode generated duplicate `WAFishMapApp.swift` / `ContentView.swift`, delete
the Xcode stubs and keep the versions already in `WAFishMap/`.

8. Confirm the scheme builds:

```zsh
cd ~/developer/wa-fish-map
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Modern Xcode folder synchronization picks up every file under `WAFishMap/` and
`WAFishMapTests/` automatically — do not hand-edit `project.pbxproj`.
