import SwiftUI
import MuralCore

struct SpainRootView: View {
    @State private var practice = TravelPractice()
    @State private var audio = TravelAudio()
    @State private var tab = 0
    @AppStorage("travel.rehearsal") private var rehearsal = false
    @AppStorage("travel.meanings") private var meanings = true
    @Environment(\.scenePhase) private var scenePhase
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--travel-ui-tests") {
            let defaults = UserDefaults(suiteName: "SpainTripUITests")!
            defaults.removePersistentDomain(forName: "SpainTripUITests")
            _practice = State(initialValue: TravelPractice(defaults: defaults))
        }
        #endif
    }
    var body: some View {
        TabView(selection: $tab) {
            Tab("Practice", systemImage: "mic", value: 0) {
                NavigationStack { TravelTalkView(practice: practice, audio: audio, rehearsal: rehearsal, meanings: $meanings) }
            }
            Tab("Situations", systemImage: "map", value: 1) {
                NavigationStack {
                    List {
                        Section {
                            Text("A little Spanish. A lot more confidence.").font(.title2.bold())
                            Text("Rehearse the moments you'll actually have in Spain. All places, prices and times in exercises are imagined.").foregroundStyle(.secondary)
                            Toggle("Rehearsal mode", isOn: $rehearsal)
                            Text("Rehearsal hides English meanings and saves feedback until the goal is complete. Applies to your next conversation.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Section("Choose a situation · \(practice.completedIDs.count) of 8 completed") {
                            ForEach(TravelScenario.all) { scenario in
                                Button {
                                    audio.silence(); practice.select(scenario, rehearsal: rehearsal); meanings = !rehearsal; tab = 0
                                } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: scenario.symbol).frame(width: 26).foregroundStyle(MuralColor.secondary)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(scenario.title).font(.headline).foregroundStyle(MuralColor.ink)
                                            Text(scenario.goal).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        if practice.completedIDs.contains(scenario.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Completed") }
                                    }.padding(.vertical, 7)
                                }.accessibilityIdentifier("scenario-\(scenario.id)")
                            }
                        }
                    }.scrollContentBackground(.hidden).background(MuralColor.cream).navigationTitle("Spain, one moment at a time")
                }
            }
            Tab("Phrasebook", systemImage: "book.closed", value: 2) {
                NavigationStack { TravelPhrasebook(audio: audio) }
            }
            Tab("Progress", systemImage: "clock", value: 3) {
                NavigationStack { TravelProgress(practice: practice) }
            }
        }
        .tint(MuralColor.ink)
        .sheet(isPresented: $practice.showSettings) { TravelSettings(practice: practice, audio: audio) }
        .onChange(of: tab) { _, _ in audio.silence() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { audio.silence(); practice.cancel() }
            else if phase == .inactive && audio.listening { audio.silence() } }
    }
}

private struct TravelTalkView: View {
    @Bindable var practice: TravelPractice
    var audio: TravelAudio
    let rehearsal: Bool
    @Binding var meanings: Bool
    @FocusState private var typing: Bool
    @State private var confirmRestart = false
    private var currentRehearsal: Bool { practice.session?.rehearsal ?? rehearsal }
    private var finished: Bool { practice.session?.completed == true || (practice.session?.turns.count ?? 0) >= TravelPracticePolicy.maximumTurns }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(currentRehearsal ? "REHEARSAL" : "TRAVEL PRACTICE", systemImage: practice.scenario.symbol).font(.caption.weight(.semibold)).foregroundStyle(MuralColor.secondary)
                        Text(practice.scenario.title).font(.largeTitle.bold())
                        Text(practice.scenario.goal).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(practice.scenario.opening.spanish).font(.title2)
                        if meanings { Text(practice.scenario.opening.english).foregroundStyle(.secondary) }
                        playback(practice.scenario.opening.spanish)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(MuralColor.butter, in: RoundedRectangle(cornerRadius: 22))
                    ForEach(practice.session?.turns ?? []) { turn in
                        VStack(alignment: .leading, spacing: 14) {
                            Text("YOU").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(turn.user).textSelection(.enabled)
                            Divider()
                            Text(turn.spanish).font(.title3).textSelection(.enabled)
                            if meanings { Text(turn.english).foregroundStyle(.secondary) }
                            playback(turn.spanish)
                            if !turn.feedback.isEmpty { Label(turn.feedback, systemImage: "lightbulb").font(.subheadline).foregroundStyle(MuralColor.secondary) }
                        }.padding(20).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22))
                    }
                    if practice.busy { ProgressView("Getting a reply…") }
                    if let error = practice.error ?? audio.error { Text(error).font(.callout).foregroundStyle(.red).accessibilityIdentifier("travel-error") }
                    if finished {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(practice.session?.completed == true ? "Goal completed" : "Time for a fresh rehearsal", systemImage: "checkmark.circle").font(.headline)
                            Text("Try again with fewer hints, or choose another situation.").foregroundStyle(.secondary)
                            Button("Start again") { restart() }.buttonStyle(.borderedProminent).tint(MuralColor.orange).foregroundStyle(MuralColor.ink)
                        }
                    } else {
                        compose
                    }
                    Text("Spanish from Spain · Short turns · No live voice session").font(.footnote).foregroundStyle(.secondary)
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(24)
            }
            .background(MuralColor.cream)
            .navigationTitle("Spain Trip").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("New", systemImage: "arrow.counterclockwise") { confirmRestart = true }.disabled(practice.busy) }
                ToolbarItem(placement: .topBarTrailing) { Button("Settings", systemImage: "slider.horizontal.3") { audio.silence(); practice.showSettings = true }.accessibilityIdentifier("travel-settings") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } }
            }
            .confirmationDialog("Start a new conversation? Saved replies stay in Progress.", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("Start again") { restart() }
            }
            .onChange(of: practice.session?.turns.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .onChange(of: audio.transcript) { _, text in if !text.isEmpty { practice.draft = String(text.prefix(600)) } }
        .onDisappear { audio.silence() }
    }
    private var compose: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Show English meanings", isOn: $meanings).font(.subheadline)
            TextField("Say it in Spanish, or type here", text: $practice.draft, axis: .vertical)
                .lineLimit(2...5).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
                .focused($typing).disabled(practice.busy || audio.listening || audio.preparing || audio.finishing).accessibilityIdentifier("travel-reply")
                .onChange(of: practice.draft) { _, value in if value.count > 600 { practice.draft = String(value.prefix(600)) } }
            HStack(spacing: 12) {
                Button {
                    typing = false
                    if audio.listening { audio.finishRecording() }
                    else if audio.preparing || audio.finishing { audio.stop() }
                    else { Task { await audio.start() } }
                } label: {
                    Label(audio.preparing || audio.finishing ? "Cancel" : audio.listening ? "Finish recording" : "Tap to talk", systemImage: audio.listening ? "stop.fill" : "mic")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered).disabled(practice.busy).accessibilityIdentifier("travel-record")
                Button {
                    typing = false; audio.silence(); practice.send(rehearsal: rehearsal)
                } label: {
                    Label("Send", systemImage: "arrow.up").frame(minHeight: 44)
                }.buttonStyle(.borderedProminent).tint(MuralColor.orange).foregroundStyle(MuralColor.ink)
                    .disabled(practice.busy || audio.listening || audio.preparing || audio.finishing || practice.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("travel-send")
            }
            if audio.preparing || audio.finishing {
                ProgressView(audio.preparationMessage).font(.footnote).accessibilityIdentifier("speech-preparation")
            }
            Text(audio.listening ? "Listening on this phone. Tap Finish recording when you're done (30 seconds maximum)." : "Record a short reply, review the words, then send. Only reviewed text goes to OpenAI. First use may download Spanish speech from Apple.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func playback(_ text: String) -> some View {
        HStack(spacing: 20) {
            Button("Listen", systemImage: "speaker.wave.2") { typing = false; audio.speak(text) }
            Button("Slower", systemImage: "tortoise") { typing = false; audio.speak(text, slow: true) }
        }.font(.subheadline).buttonStyle(.borderless).disabled(practice.busy || audio.listening || audio.preparing || audio.finishing)
    }
    private func restart() { audio.silence(); practice.select(practice.scenario, rehearsal: rehearsal); meanings = !rehearsal }
}

private struct TravelPhrasebook: View {
    var audio: TravelAudio
    @State private var search = ""
    @AppStorage("travel.favorites") private var favorites = ""
    @State private var onlyFavorites = false
    private func saved(_ phrase: TravelPhrase) -> Bool { favorites.components(separatedBy: "\n").contains(phrase.id) }
    private func matches(_ phrase: TravelPhrase) -> Bool {
        (!onlyFavorites || saved(phrase)) && (search.isEmpty || phrase.spanish.localizedStandardContains(search) || phrase.english.localizedStandardContains(search))
    }
    var body: some View {
        List {
            Section {
                Label("Ready without internet", systemImage: "wifi.slash").font(.headline)
                Text("All phrases are bundled with the app. Listening uses your phone's installed Spanish voice. Sentences with … need your own details.").font(.subheadline).foregroundStyle(.secondary)
                Toggle("Saved phrases only", isOn: $onlyFavorites)
            }
            ForEach(TravelScenario.all) { scenario in
                let phrases = scenario.phrases.filter(matches)
                if !phrases.isEmpty {
                    Section(scenario.title) {
                        ForEach(phrases) { phrase in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(phrase.spanish).font(.headline).textSelection(.enabled)
                                Text(phrase.english).foregroundStyle(.secondary)
                                HStack {
                                    Button("Listen", systemImage: "speaker.wave.2") { audio.speak(phrase.spanish) }
                                    Button("Slower", systemImage: "tortoise") { audio.speak(phrase.spanish, slow: true) }
                                    Spacer()
                                    Button(saved(phrase) ? "Unsave" : "Save", systemImage: saved(phrase) ? "bookmark.fill" : "bookmark") {
                                        var ids = Set(favorites.components(separatedBy: "\n").filter { !$0.isEmpty })
                                        if saved(phrase) { ids.remove(phrase.id) } else { ids.insert(phrase.id) }
                                        favorites = ids.sorted().joined(separator: "\n")
                                    }.labelStyle(.iconOnly).accessibilityLabel(saved(phrase) ? "Unsave \(phrase.english)" : "Save \(phrase.english)")
                                }.buttonStyle(.borderless).font(.subheadline)
                            }.padding(.vertical, 6)
                        }
                    }
                }
            }
            if !TravelScenario.all.flatMap(\.phrases).contains(where: matches) {
                ContentUnavailableView("No matching phrases", systemImage: "magnifyingglass", description: Text("Try another word or turn off Saved phrases only."))
            }
            if let error = audio.error { Text(error).foregroundStyle(.red) }
        }.searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Spanish or English")
            .scrollContentBackground(.hidden).background(MuralColor.cream).navigationTitle("Your pocket Spanish")
            .onDisappear { audio.silence() }
    }
}

private struct TravelProgress: View {
    var practice: TravelPractice
    var body: some View {
        List {
            Section {
                Text("\(practice.completedIDs.count) of 8 situations completed").font(.title2.bold())
                Text("A completed role-play is practice evidence, not a fluency score. Repeat it without hints to test your recall.").foregroundStyle(.secondary)
            }
            if practice.sessions.isEmpty { ContentUnavailableView("Your first conversation awaits", systemImage: "bubble.left.and.bubble.right", description: Text("Choose a situation, then send a reply. Your conversations stay on this phone.")) }
            ForEach(practice.sessions) { session in
                NavigationLink {
                    List {
                        Text(session.rehearsal ? "Rehearsal" : "Practice").font(.headline)
                        ForEach(session.turns) { turn in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("You: \(turn.user)")
                                Text(turn.spanish).font(.headline)
                                Text(turn.english).foregroundStyle(.secondary)
                                if !turn.feedback.isEmpty { Text(turn.feedback).font(.subheadline) }
                            }.padding(.vertical, 6).textSelection(.enabled)
                        }
                    }.navigationTitle(TravelScenario.all.first { $0.id == session.scenarioID }?.title ?? "Conversation")
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(TravelScenario.all.first { $0.id == session.scenarioID }?.title ?? "Conversation").font(.headline)
                        Text(session.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        Text("\(session.turns.count) replies · \(session.completed ? "Goal completed" : "In progress")").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(MuralColor.cream).navigationTitle("Little by little")
    }
}

private struct TravelSettings: View {
    var practice: TravelPractice
    var audio: TravelAudio
    @State private var key = ""
    @State private var hasKey = CredentialStore.hasKey
    @State private var error: String?
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Economical practice") {
                    Text("Speech is transcribed on this iPhone. When you tap Send, your reviewed text and a short conversation context go directly to OpenAI. Replies are spoken by your phone. No live audio session, automatic web searches or separate translation calls.")
                    Toggle("Allow text processing by OpenAI", isOn: Binding(get: { practice.consent }, set: { practice.setConsent($0) }))
                    Text("OpenAI API billing is separate from ChatGPT. Provider retention settings still apply, even though requests use store: false.").font(.footnote).foregroundStyle(.secondary)
                    Link("OpenAI data controls", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                }
                Section("Your OpenAI API key") {
                    Text(hasKey ? "A key is saved in this phone's Keychain." : "Add your own key to enable conversations. The phrasebook works without one.")
                    SecureField("sk-…", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive().accessibilityIdentifier("travel-api-key")
                    Button("Save key") {
                        do { try CredentialStore.save(key); key = ""; hasKey = true; error = nil }
                        catch { self.error = error.localizedDescription }
                    }.disabled(key.isEmpty)
                    if hasKey {
                        Button("Remove key", role: .destructive) {
                            practice.cancel()
                            do { try CredentialStore.delete(); hasKey = false; error = nil } catch { self.error = error.localizedDescription }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                Section("Usage controls") {
                    LabeledContent("Requests today", value: "\(practice.requestsToday) / 80")
                    LabeledContent("Model", value: TravelPracticePolicy.model)
                    LabeledContent("Reported input tokens", value: practice.inputTokens.formatted())
                    LabeledContent("Reported output tokens", value: practice.outputTokens.formatted())
                    Text("One request per Send. Replies are limited to 500 output tokens; each scenario allows 12 turns. Failed requests count toward the daily limit. Token totals include successful responses received by this app and can miss cancelled requests. This isn't an OpenAI billing cap.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("On this phone") {
                    Text("The latest 24 conversations are kept here. Raw microphone audio is never saved. No Mural account or hosted backend is used.")
                    Button("Delete saved practice", role: .destructive) { confirmDelete = true }
                }
                Section("About") {
                    Text("Spain Trip · A personal adaptation of Mural")
                    Text("Mural is MIT licensed. Original software © 2026 Hackmamba. This fork is independent of Mural's hosted service.").font(.footnote)
                    Link("Original project & license", destination: URL(string: "https://github.com/Chuloo/mural")!)
                }
            }.navigationTitle("Settings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Delete all saved practice on this phone?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete practice", role: .destructive) { audio.silence(); practice.deletePractice() }
                }
        }.onDisappear { key = "" }
    }
}
