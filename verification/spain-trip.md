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
- Build 2: archive passed; export/upload and processing status recorded below when complete.

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
