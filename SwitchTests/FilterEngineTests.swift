import XCTest
@testable import Switch

final class FilterEngineTests: XCTestCase {
    func testEmptyFilterMatchesEverything() {
        XCTAssertTrue(FilterEngine.matches(haystack: "Safari", filter: ""))
        XCTAssertTrue(FilterEngine.matches(haystack: "", filter: ""))
    }

    func testSubstringMatch() {
        XCTAssertTrue(FilterEngine.matches(haystack: "Safari", filter: "saf"))
        XCTAssertTrue(FilterEngine.matches(haystack: "Google Chrome", filter: "chr"))
        XCTAssertFalse(FilterEngine.matches(haystack: "Safari", filter: "xyz"))
    }

    func testMultiTokenAllMustMatch() {
        // tokens are whitespace-separated; every token must appear (independent order)
        XCTAssertTrue(FilterEngine.matches(haystack: "Safari — Apple", filter: "saf app"))
        XCTAssertTrue(FilterEngine.matches(haystack: "Safari — Apple", filter: "app saf"))
        XCTAssertFalse(FilterEngine.matches(haystack: "Safari — Apple", filter: "saf xyz"))
    }

    func testDiacriticAndCaseFolding() {
        XCTAssertTrue(FilterEngine.matches(haystack: "Café", filter: "cafe"))
        XCTAssertTrue(FilterEngine.matches(haystack: "naïve", filter: "NAIVE"))
        XCTAssertTrue(FilterEngine.matches(haystack: "Pokémon", filter: "pokemon"))
    }

    func testWhitespaceOnlyFilterMatchesEverything() {
        XCTAssertTrue(FilterEngine.matches(haystack: "Safari", filter: "   "))
    }
}
