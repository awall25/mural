import Foundation
import Testing
@testable import MuralCore

struct SpainTravelTests {
    @Test func contextIsBoundedAndPreservesLatestReply() throws {
        let turns = (0..<11).map { _ in TravelTurn(user: String(repeating: "u", count: 900), spanish: String(repeating: "a", count: 1500), english: "", feedback: "", complete: false) }
        let input = try TravelPracticePolicy.input(scenario: TravelScenario.all[0], turns: turns, draft: "  ¿Y la cuenta?  ")
        let json = try #require(JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: Any])
        let recent = try #require(json["recent_turns"] as? [[String: String]])
        #expect(recent.count == 6)
        #expect(recent.allSatisfy { $0["user"]?.count == 600 && $0["assistant"]?.count == 1200 })
        #expect(json["latest_user_reply"] as? String == "¿Y la cuenta?")
    }
    @Test func limitsRejectWithoutSendingTruncatedInput() throws {
        let scenario = TravelScenario.all[0]
        for draft in ["   ", String(repeating: "x", count: 601)] {
            #expect(throws: TravelPracticePolicy.InputError.self) { try TravelPracticePolicy.input(scenario: scenario, turns: [], draft: draft) }
        }
        let turns = (0..<12).map { _ in TravelTurn(user: "Hola", spanish: "Hola", english: "Hi", feedback: "", complete: false) }
        #expect(throws: TravelPracticePolicy.InputError.self) { try TravelPracticePolicy.input(scenario: scenario, turns: turns, draft: "Hola") }
    }
    @Test func invalidAndOversizedProviderRepliesAreRejected() throws {
        #expect(throws: (any Error).self) { try TravelReply.decode("{\"spanish\":\"hola\"}") }
        for spanish in [" ", String(repeating: "x", count: 1201)] {
            let data = try JSONSerialization.data(withJSONObject: ["spanish": spanish, "english": "Hello", "feedback": "", "complete": false])
            #expect(throws: TravelReply.ReplyError.self) { try TravelReply.decode(String(decoding: data, as: UTF8.self)) }
        }
        let reply = try TravelReply.decode("{\"spanish\":\"¿Qué te pongo?\",\"english\":\"What can I get you?\",\"feedback\":\"\",\"complete\":false}")
        #expect(reply.spanish == "¿Qué te pongo?")
        #expect(!reply.complete)
    }
    @Test func travelContentIncludesRepairAndEveryRequestedSetting() {
        let ids = Set(TravelScenario.all.map(\.id))
        #expect(ids.count == TravelScenario.all.count)
        #expect(Set(["restaurant", "hotel", "taxi", "train", "locals", "repair"]).isSubset(of: ids))
        for scenario in TravelScenario.all {
            #expect(!scenario.phrases.isEmpty)
            #expect(Set(scenario.phrases.map(\.id)).count == scenario.phrases.count)
        }
    }
}
