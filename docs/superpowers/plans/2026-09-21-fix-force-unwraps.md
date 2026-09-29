# Fix Force-Unwrapped URLs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Safely construct URLs in data loaders (`NDBCLoader`) instead of using force-unwraps (`!`), avoiding potential crashes on malformed upstream string components.

**Architecture:** We will replace `URL(string:)!` with a guarded construction. When construction fails, the loader should throw a specific error instead of crashing. `NOAATideLoader` and `USGSFlowLoader` currently use static strings and `!` which are functionally safe, so we will focus specifically on upgrading `NDBCLoader.observationsURL(stationID:)` to throw if the station ID yields an invalid URL, since it incorporates dynamic arguments.

**Tech Stack:** Swift, Foundation

## Global Constraints

- No force unwraps (`!`) in dynamic URL initializers.
- Throw custom module errors (e.g. `NDBCError.invalidURL`) rather than crashing.

---

### Task 1: Update NDBCError and NDBCLoader URL Construction

**Files:**
- Modify: `WAFishMap/Services/NDBCLoader.swift`

**Interfaces:**
- Produces: `NDBCLoader.observationsURL(stationID: String) throws -> URL`

- [ ] **Step 1: Add `invalidURL` to `NDBCError`**

In `WAFishMap/Services/NDBCLoader.swift`, add the `invalidURL` case to the `NDBCError` enum.

```swift
enum NDBCError: Error, Equatable {
    case missingBundleResource
    case malformedHeader
    case noRows
    case invalidURL
}
```

- [ ] **Step 2: Update `observationsURL(stationID:)` to throw**

In `WAFishMap/Services/NDBCLoader.swift`, replace the force-unwrapped URL function with a throwing one.

```swift
    static func observationsURL(stationID: String) throws -> URL {
        guard let url = URL(string: "\(endpoint)/\(stationID).txt") else {
            throw NDBCError.invalidURL
        }
        return url
    }
```

*(Note: The caller in `BuoyConditionsView.swift:104` is already wrapped in `try await`, so it will automatically absorb the new throwing signature without modification.)*

- [ ] **Step 3: Run the compiler to verify it passes**

Run: `xcodebuild -scheme WAFishMap -destination 'generic/platform=iOS Simulator' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WAFishMap/Services/NDBCLoader.swift
git commit -m "fix: safely construct NDBC observation URL to prevent crashes"
```
