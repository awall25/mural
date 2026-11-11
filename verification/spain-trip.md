# Spain Trip validation — November 11, 2026

## Passed locally

- 202 existing Swift core XCTest cases; 4 new Swift Testing cases.
- 91 Python script tests; Android content export check and cross-platform contract check.
- iOS Simulator build and launch on iOS 27.
- Four native UI cases: offline launch/hotel selection; offline phrase search; empty progress; consent/key gate before sending. Initial phrase-search failure was corrected by making the navigation search field consistently visible; the affected test passed on rerun.
- Signed Release archive and export, team L484ETZTGA, separate bundle com.awall25.spaintrip.
- IPA signature, version/build, bundle identity, iPhone device family, microphone/speech permission descriptions, no background-audio mode, disabled hosted/account/purchase settings, distribution entitlements and absence of debug entitlement.

## Apple processing

- App record: Spain Trip Practice (6833642049).
- Internal group: Personal Testing.
- Build 1 uploaded but failed validation with 90683 (missing purpose string). Restored the camera purpose declaration required by the retained upstream WebRTC binary. Spain travel does not invoke camera capture or request camera permission.
- Build 2: signed archive/export and IPA verification passed. Apple processing state **VALID**; internal build state **IN_BETA_TESTING**. Build ID `64463451-2afe-4a9d-ba8b-6e2d15f1c847`; verified in Personal Testing group. Invitation sent to the owner only. Expires **February 9, 2027**. App source commit: `e3bf0a8`.

## Scoped privacy preflight

- Required-reason declarations retained for UserDefaults (CA92.1) and interval timing (35F9.1); upstream framework privacy manifest remains bundled.
- App collection manifest narrowed to user content for functionality; account, advertising and purchase data declarations removed from this fork.
- Personal Keychain key is sent only to the fixed OpenAI HTTPS endpoint; no raw audio storage or audio upload in the travel flow.
- Explicit text-processing consent and a reviewed transcript are required before sending. Consent withdrawal cancels the current request.
- No tracking, social login, account registration, hosted Mural service or in-app purchases in the travel interface.
- Public App Store release has not been prepared or requested. This is internal personal TestFlight distribution; no external beta review or public listing submission is configured.

## Remaining physical-device validation

Spanish recognition availability/accuracy, microphone permissions, headphones/speaker, normal and slower Spanish voice playback, background/interruption behavior, and a real model conversation require the owner's iPhone and API key. Offline UI tests make no provider calls. Recognition availability is checked at runtime; typing remains available if unsupported. Model output quality and task-completion decisions are not established by transport/schema tests.

No backend deployment is needed: the new entry point uses local speech and the user's direct OpenAI API key. Money Bot files were read/copied as permitted, and were not modified.


## Build 3 — Spanish recognition setup fix

Reported on the owner's iPhone 18 Pro running iOS 27.2. Build 2 combined legacy `supportsOnDeviceRecognition` and service `isAvailable` in one gate, did not install Spanish recognition assets, and could cancel preparation when a permission prompt made the app inactive. This did not establish a hardware limitation.

Build 3 prefers `SpeechAnalyzer` with `SpeechTranscriber` and uses `AssetInventory` to install the equivalent Spain Spanish model. Download/startup progress and cancellation are visible. It converts microphone buffers to the compatible format, retains committed transcript segments while replacing interim text, and finalizes input before enabling edits/Send. Legacy on-device recognition remains only as a compatibility fallback, without the old service-availability gate. Backgrounding still cancels speech; permission prompts no longer cancel preparation. Menu label changed to **Practice**.

Validation: 202 existing core tests and 5 travel tests passed. All 4 native UI tests passed; the offline-launch/hotel-selection test was rerun with an explicit assertion for the **Practice** menu label and passed. Simulator compilation passed. No paid API calls were made. Real Spanish model installation and spoken recognition on the owner's phone still require retesting after updating. No backend changes or deployment needed.

Build 3 archive/export passed and Apple marked it VALID. Final audio-session review found that the recording-only category inherited an incompatible duckOthers option. Build 3 was removed from the Personal Testing group before recommending installation; build 4 replaces it.


## Build 4 — corrected microphone session

Retains all build 3 speech/setup and Practice-label changes. Both recognizer paths now use recording-only measurement mode with no incompatible category options. Playback retains duckOthers only with the supported playback category. A standalone iOS Simulator runtime check accepted both audio-session configurations without activating the microphone or making provider calls. Signed build 4 archive/export and package verification passed. Apple processing/distribution status will be recorded after completion.
