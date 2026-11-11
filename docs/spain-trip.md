# Spain Trip personal fork

## What is implemented

The iOS entry point launches `SpainRootView`, independent of Mural's live coordinator. Eight bundled scenarios cover restaurants, cafés, hotels, taxis/rideshare pickup, trains, directions, chatting with locals and conversation repair. There are 39 offline phrases, searchable in English/Spanish, with saved phrases and normal/slower `es-ES` device speech. Places, times and prices used by the model are fictional exercises.

Speech prefers Apple's `SpeechAnalyzer`/`SpeechTranscriber` and installs the supported Spain Spanish model through `AssetInventory`. The app shows downloading/starting progress and offers Cancel. Older-device compatibility uses `SFSpeechRecognizer` only with `requiresOnDeviceRecognition = true`, gated by `supportsOnDeviceRecognition`; it does not conflate the legacy service's `isAvailable` flag with installed-model support. Tap to start, tap to finish (30-second maximum), wait for the final transcript, edit it, then Send. Finalization is bounded to five seconds; partial text is preserved on timeout. Microphone buffers are converted into the analyzer's compatible format and copied before the engine reuses them. Permission prompts do not cancel setup; backgrounding does. Permission denial or unavailable recognition leaves typing available; there is no cloud recognition fallback. Backgrounding, interruptions and navigation stop recording/playback. Downloaded Spanish voice/speech resources and physical-device checks remain important.

The curriculum has **26 tasks** across eight scenarios. Each task includes an English objective, a bundled Spanish local-person line and English meaning, explicit passing criteria, and an optional Spanish example. The screen shows one task, its progress and feedback. An unrelated or incomplete answer stays on the same task. Help requests reveal a hint. Passing unlocks **Next task**; only ordered passes for every task complete the scenario. Valid alternative wording and minor errors that do not change meaning are accepted by the assessor. Hinted passes are marked as assisted.

**Check reply** uses the existing ephemeral, redirect-rejecting API transport with a personal Keychain key and explicit text-processing consent. It sends the current task instructions/criteria and latest user reply only, with no previous exchanges. The request uses the Responses API, `gpt-4.1-mini`, `store: false`, a strict assessment schema and 300 maximum output tokens. The response contains the expected task ID, one of passed/retry/off_topic/needs_help, and mandatory short feedback. Wrong-task or invalid responses cannot advance progress. The app chooses the next bundled prompt; the model cannot end the whole scenario through a completion flag. There are no web tools, automatic translations, live sessions or extra assessment calls.

Replies are limited to 1–600 characters. Scenarios stop after all tasks pass or 24 attempts. Reaching the attempt limit does not count as completion. The app permits 80 request attempts per device-local calendar day. This is a convenience guard, not an account-level billing cap; cancellations can still incur provider charges. Settings shows token counts received in completed responses and may omit cancelled requests.

Practice transcripts and completion markers live in UserDefaults, bounded to the latest 24 conversations. Existing free-conversation records decode without task metadata and remain readable; they do not count toward structured lesson completions. Keys and raw audio are never included. Settings can delete practice, revoke consent and remove the key. A corrupt journal is retained rather than overwritten; saved practice must be explicitly deleted to restore persistent recording of new sessions.

## Development

- Xcode project: `apps/ios/Mural.xcodeproj`; scheme: `Mural`.
- Display name: Spain Trip; bundle: `com.awall25.spaintrip`.
- Minimum iOS: 26.1; iPhone only.
- Team: `L484ETZTGA`, reused from Finbot's setup with permission. Money Bot source/configuration is not modified.
- Managed Mural service, account providers and purchases are disabled. No backend deployment is necessary.
- The original live implementation remains compiled as upstream reference but is not reachable from the travel root. Android is unchanged and does not include these features.

```
swift test --package-path apps/ios
python3 -m unittest discover -s scripts/tests -t .
python3 scripts/generate_project.py
```

The project generator uses `TravelUITests.swift` for this fork's native tests. Upstream `MuralUITests.swift` remains as reference for the original interface. The core and script suites retain upstream coverage. New core tests cover bounded context, input/session limits, provider output validation and requested travel content. UI tests cover offline launch, hotel selection, offline phrase search, empty progress and the consent/key gate before any network request.

## Signing and TestFlight

App Store Connect record: **Spain Trip Practice**, ID **6833642049**.

- Bundle registration: `RHWWH4Q7K5`.
- Distribution profile: **Spain Trip App Store Distribution**, ID `A45Z828N5X`.
- Existing Apple Distribution certificate: `FR6GUXS4UH`.
- Internal group: **Personal Testing**, ID `f1340caa-5bd1-4fc3-8df4-b1bd9b0d1e2e`.
- `.asc/` contains ignored local ASC configuration and build artifacts. It references the existing private key by path; no private key is copied into source control.
- `scripts/prepare-spain-signing.py` is copied from Finbot's signing helper. It unlocks the existing dedicated distribution keychain using its existing owner-only password file, without changing Money Bot files.
- App-specific manual Release signing is set in `scripts/generate_project.py`; Debug remains automatic.
- `apps/ios/ExportOptions.plist` selects only Spain Trip's new profile. Never reuse Finbot's provisioning profile for this bundle.

```
python3 scripts/prepare-spain-signing.py
xcodebuild -project apps/ios/Mural.xcodeproj -scheme Mural -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData \
  -archivePath .asc/SpainTrip.xcarchive archive
xcodebuild -exportArchive -archivePath .asc/SpainTrip.xcarchive \
  -exportOptionsPlist apps/ios/ExportOptions.plist -exportPath .asc/export
python3 scripts/verify-spain-ipa.py .asc/export/Mural.ipa BUILD_NUMBER
asc publish testflight --app 6833642049 --ipa .asc/export/Mural.ipa \
  --group f1340caa-5bd1-4fc3-8df4-b1bd9b0d1e2e --wait
```

Increment `CURRENT_PROJECT_VERSION` in the generator before subsequent uploads and regenerate the project. Use a fresh archive/export directory per release. The package verification script checks nonblank packaged icon artwork, signature, bundle, version/build, permissions (including the camera purpose declaration required by the retained WebRTC binary), device family, disabled hosted settings and distribution entitlements. No push entitlement is needed for this app.

## Current release

**1.0 (4)** is valid as of November 11, 2026. Build ID `857600b9-a4bd-4c99-81c5-d26b8bd27c55`; assigned to Personal Testing. App source commit: `eb118af`.

Update through TestFlight without uninstalling to retain the saved API key. Connect to Wi-Fi for the initial Spanish recognizer-model download, tap **Tap to talk**, and wait for setup to finish. Model download uses Apple's servers; microphone audio remains local. This release also corrects the **Practice** menu label. A real spoken retest on the owner's iPhone 18 Pro / iOS 27.2 is pending.

## First iPhone check

1. Install Spain Trip in TestFlight. Phrasebook should open without a key or internet.
2. In Settings, enter an OpenAI project key directly and enable text processing. Never paste it into chat or commit it.
3. Choose a situation, tap to talk, grant microphone/speech permissions, and speak a brief Spanish reply. Review and edit the transcript before Send.
4. Answer the displayed task, tap Check reply and inspect its feedback. Try an unrelated answer and an answer missing a required detail: both should stay on that task. Then give a complete Spanish answer, confirm Next task unlocks, and continue. Check billing in the OpenAI project.
5. Try a hint, confirm assisted passes are marked, finish all tasks, and revisit Progress. Try rehearsal without meanings and test speaker/headphones plus recording interruption/backgrounding.
6. In airplane mode, verify phrase search, saved phrases and installed-voice playback. AI conversation requires internet.

Simulator tests do not establish Spanish recognition accuracy, pronunciation quality, teaching effectiveness or real API access. A real spoken conversation is still needed.

## Scope

This is a personal travel refresher, not a general-language curriculum, real-time translator, itinerary service or booking tool. No App Store public release or external tester invitations are configured. MIT license and upstream notices are retained; the geometric Spain Trip icon is original and reproducible with `scripts/draw_spain_icon.swift`.
