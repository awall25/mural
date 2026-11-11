import Foundation
import Observation
import MuralCore

struct TravelSession: Codable, Identifiable {
    var id = UUID()
    var scenarioID: String
    var date = Date()
    var rehearsal: Bool
    var turns: [TravelTurn] = []
    var completed: Bool { turns.last?.complete == true }
}

private struct TravelJournal: Codable {
    var sessions: [TravelSession] = []
    var requestDay = ""
    var requests = 0
    var inputTokens = 0
    var outputTokens = 0
}

@MainActor @Observable final class TravelPractice {
    var scenario = TravelScenario.all[0]
    var session: TravelSession?
    var busy = false
    var error: String?
    var showSettings = false
    var draft = ""
    private(set) var sessions: [TravelSession] = []
    private(set) var inputTokens = 0
    private(set) var outputTokens = 0
    private var journal = TravelJournal()
    private let defaults: UserDefaults
    private let api = APIClient()
    private var pending: Task<Void, Never>?
    private var generation = UUID()
    private var journalWritable = true
    var consent: Bool { defaults.bool(forKey: "travel.textConsent.v1") }
    var completedIDs: Set<String> { Set(sessions.filter(\.completed).map(\.scenarioID)) }
    var requestsToday: Int { journal.requestDay == Self.dayKey() ? journal.requests : 0 }
    static let dailyRequestLimit = 80
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "travel.journal.v1") {
            do {
                journal = try JSONDecoder().decode(TravelJournal.self, from: data)
                sessions = journal.sessions; inputTokens = journal.inputTokens; outputTokens = journal.outputTokens
            } catch {
                journalWritable = false
                self.error = "Your saved practice couldn't be opened. It has been kept. You can still practise, or delete the saved practice in Settings to start fresh."
            }
        }
        api.canProcessAI = { [weak self] in self?.consent == true }
    }
    func setConsent(_ allowed: Bool) {
        defaults.set(allowed, forKey: "travel.textConsent.v1")
        if !allowed { cancel() }
    }
    func select(_ scenario: TravelScenario, rehearsal: Bool) {
        cancel(); self.scenario = scenario
        session = TravelSession(scenarioID: scenario.id, rehearsal: rehearsal)
        draft = ""
    }
    func cancel() {
        generation = UUID(); pending?.cancel(); pending = nil; api.cancelAIRequests(); busy = false
    }
    func send(rehearsal: Bool) {
        guard !busy else { return }
        guard consent, CredentialStore.hasKey else { showSettings = true; return }
        guard requestsToday < Self.dailyRequestLimit else { error = "You've reached today's 80-request limit. Offline phrases are still available."; return }
        if session == nil { session = TravelSession(scenarioID: scenario.id, rehearsal: rehearsal) }
        guard let current = session, !current.completed else { return }
        let input: String
        do { input = try TravelPracticePolicy.input(scenario: scenario, turns: current.turns, draft: draft) }
        catch { self.error = "Use a reply of 1–600 characters. After 12 replies, start a new rehearsal."; return }
        let userReply = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = TravelPracticePolicy.instructions(scenario: scenario, rehearsal: current.rehearsal)
        busy = true; error = nil
        let ticket = generation
        let nextCount = requestsToday + 1
        journal.requestDay = Self.dayKey(); journal.requests = nextCount
        persist()
        pending = Task { [weak self] in
            guard let self else { return }
            defer { if generation == ticket { busy = false; pending = nil } }
            do {
                let result = try await api.travelReply(instructions: instruction, input: input)
                try Task.checkCancellation()
                guard generation == ticket, consent else { return }
                // Account for billed responses even when the returned content fails validation.
                journal.inputTokens += result.usage.input; journal.outputTokens += result.usage.output
                inputTokens = journal.inputTokens; outputTokens = journal.outputTokens
                persist()
                let reply = try TravelReply.decode(result.text)
                let turn = TravelTurn(user: userReply, spanish: reply.spanish, english: reply.english, feedback: reply.feedback, complete: reply.complete)
                session?.turns.append(turn); draft = ""
                if let session {
                    journal.sessions.removeAll { $0.id == session.id }
                    journal.sessions.insert(session, at: 0)
                    journal.sessions = Array(journal.sessions.prefix(24)); sessions = journal.sessions
                }
                persist()
            } catch is CancellationError { }
            catch {
                guard generation == ticket else { return }
                self.error = "Couldn't get a reply. Your text is still here. Check your connection, API key and OpenAI billing, then try again."
            }
        }
    }
    func deletePractice() {
        cancel(); journal = TravelJournal(); journalWritable = true; sessions = []; session = nil; draft = ""
        inputTokens = 0; outputTokens = 0; persist()
    }
    private func persist() {
        guard journalWritable else { return }
        do { defaults.set(try JSONEncoder().encode(journal), forKey: "travel.journal.v1") }
        catch { self.error = "Your practice couldn't be saved on this phone." }
    }
    private static func dayKey() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

extension APIClient {
    func travelReply(instructions: String, input: String) async throws -> APIResult {
        let fields: [String: Any] = ["spanish": ["type": "string"], "english": ["type": "string"], "feedback": ["type": "string"], "complete": ["type": "boolean"]]
        let schema: [String: Any] = ["type": "object", "properties": fields, "required": fields.keys.sorted(), "additionalProperties": false]
        let json = try await post("responses", body: [
            "model": TravelPracticePolicy.model, "store": false, "instructions": instructions,
            "input": [["role": "user", "content": input]], "max_output_tokens": 500,
            "text": ["format": ["type": "json_schema", "name": "travel_reply", "strict": true, "schema": schema]]
        ])
        guard json["status"] as? String == "completed" else { throw APIError.incomplete }
        var text = ""
        for item in json["output"] as? [[String: Any]] ?? [] {
            for content in item["content"] as? [[String: Any]] ?? [] {
                if content["type"] as? String == "refusal" { throw APIError.refused }
                if content["type"] as? String == "output_text" { text += content["text"] as? String ?? "" }
            }
        }
        let usage = json["usage"] as? [String: Any] ?? [:]
        return APIResult(text: text, sources: [], usage: APIUsage(input: usage["input_tokens"] as? Int ?? 0, output: usage["output_tokens"] as? Int ?? 0))
    }
}
