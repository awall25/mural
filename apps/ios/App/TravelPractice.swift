import Foundation
import Observation
import MuralCore

struct TravelSession: Codable, Identifiable {
    var id = UUID()
    var scenarioID: String
    var date = Date()
    var rehearsal: Bool
    var turns: [TravelTurn] = []
    var lessonVersion: Int? = 1
    var completed: Bool {
        if lessonVersion == 1 { return TravelLesson.forScenario(scenarioID).activeTask(in: turns) == nil }
        return turns.last?.complete == true
    }
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
    var awaitingNextTask = false
    var hintVisible = false
    private(set) var sessions: [TravelSession] = []
    private(set) var inputTokens = 0
    private(set) var outputTokens = 0
    private var journal = TravelJournal()
    private let assessmentOverride: (@MainActor (String, String) async throws -> APIResult)?
    private let credentialAvailable: @MainActor () -> Bool
    private let defaults: UserDefaults
    private let api = APIClient()
    private var pending: Task<Void, Never>?
    private var generation = UUID()
    private var journalWritable = true
    var consent: Bool { defaults.bool(forKey: "travel.textConsent.v1") }
    var completedIDs: Set<String> { Set(sessions.filter { $0.lessonVersion == 1 && $0.completed }.map(\.scenarioID)) }
    var lesson: TravelLesson { .forScenario(scenario.id) }
    var passedTasks: Int { lesson.passedCount(in: session?.turns ?? []) }
    var activeTask: TravelTask? {
        let index = awaitingNextTask ? max(0, passedTasks - 1) : passedTasks
        return index < lesson.tasks.count ? lesson.tasks[index] : nil
    }
    func nextTask() { awaitingNextTask = false; hintVisible = false; draft = "" }
    func revealHint() { hintVisible = true }
    var requestsToday: Int { journal.requestDay == Self.dayKey() ? journal.requests : 0 }
    static let dailyRequestLimit = 80
    init(defaults: UserDefaults = .standard,
         assessment: (@MainActor (String, String) async throws -> APIResult)? = nil,
         credentialAvailable: @escaping @MainActor () -> Bool = { CredentialStore.hasKey }) {
        self.defaults = defaults; self.assessmentOverride = assessment; self.credentialAvailable = credentialAvailable
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
        draft = ""; awaitingNextTask = false; hintVisible = false
    }
    func cancel() {
        generation = UUID(); pending?.cancel(); pending = nil; api.cancelAIRequests(); busy = false
    }
    func send(rehearsal: Bool) {
        guard !busy, !awaitingNextTask else { return }
        guard consent, credentialAvailable() else { showSettings = true; return }
        guard requestsToday < Self.dailyRequestLimit else { error = "You've reached today's 80-request limit. Offline phrases are still available."; return }
        if session == nil { session = TravelSession(scenarioID: scenario.id, rehearsal: rehearsal) }
        guard let current = session, !current.completed, let task = activeTask else { return }
        guard current.turns.count < TravelPracticePolicy.maximumTurns else { error = "You've reached this session's 24-attempt limit. Start again to keep practicing."; return }
        let input: String
        do { input = try TravelTaskPolicy.input(task: task, draft: draft) }
        catch { self.error = "Use a reply of 1–600 characters. After 24 attempts, start again."; return }
        let userReply = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = TravelTaskPolicy.instructions(task: task)
        let usedHint = hintVisible
        busy = true; error = nil
        let ticket = generation
        let nextCount = requestsToday + 1
        journal.requestDay = Self.dayKey(); journal.requests = nextCount
        persist()
        pending = Task { [weak self] in
            guard let self else { return }
            defer { if generation == ticket { busy = false; pending = nil } }
            do {
                let result: APIResult
                if let assessmentOverride { result = try await assessmentOverride(instruction, input) }
                else { result = try await api.travelReply(instructions: instruction, input: input) }
                try Task.checkCancellation()
                guard generation == ticket, consent else { return }
                // Account for billed responses even when the returned content fails validation.
                journal.inputTokens += result.usage.input; journal.outputTokens += result.usage.output
                inputTokens = journal.inputTokens; outputTokens = journal.outputTokens
                persist()
                let assessment = try TravelTaskAssessment.decode(result.text, for: task)
                let complete = assessment.outcome == .passed && passedTasks + 1 == lesson.tasks.count
                let turn = TravelTurn(user: userReply, spanish: task.prompt.spanish, english: task.prompt.english,
                                      feedback: assessment.feedback, complete: complete, taskID: task.id,
                                      outcome: assessment.outcome, usedHint: usedHint)
                session?.turns.append(turn)
                awaitingNextTask = assessment.outcome == .passed && !complete
                if assessment.outcome == .needsHelp { hintVisible = true }
                draft = assessment.outcome == .passed ? "" : userReply
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
        inputTokens = 0; outputTokens = 0; awaitingNextTask = false; hintVisible = false; persist()
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
        let fields: [String: Any] = ["task_id": ["type": "string"], "outcome": ["type": "string", "enum": ["passed", "retry", "off_topic", "needs_help"]], "feedback": ["type": "string"]]
        let schema: [String: Any] = ["type": "object", "properties": fields, "required": fields.keys.sorted(), "additionalProperties": false]
        let json = try await post("responses", body: [
            "model": TravelPracticePolicy.model, "store": false, "instructions": instructions,
            "input": [["role": "user", "content": input]], "max_output_tokens": 300,
            "text": ["format": ["type": "json_schema", "name": "travel_task_assessment", "strict": true, "schema": schema]]
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
