import XCTest
@testable import CornucopiaHTTP

let serverPrefix = "http://localhost.proxyman.io:3000"

struct Subject: Codable {
    let id: Int?
    var name: String?
}

final class CornucopiaHTTPTests: XCTestCase {

    func testGET() async throws {
        
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        let subjects: [Subject] = try await HTTP.GET(from: URLRequest(url: subjectsUrl))
        print(subjects)
        XCTAssertGreaterThan(subjects.count, 1)
    }

    func testPOST() async throws {
        
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        let newSubject = Subject(id: nil, name: "Hans Wurst")
        let returnedSubject = try await HTTP.POST(item: newSubject, to: URLRequest(url: subjectsUrl))
        XCTAssertEqual(newSubject.name, returnedSubject.name)
    }

    func testPUT() async throws {
        
        let subjectUrl = URL(string: "\(serverPrefix)/subjects/1")!
        var subject: Subject = try await HTTP.GET(from: URLRequest(url: subjectUrl))
        subject.name = "name has changed"
        let updatedSubject = try await HTTP.PUT(item: subject, to: URLRequest(url: subjectUrl))
        XCTAssertEqual(subject.id, updatedSubject.id)
        XCTAssertEqual(subject.name, updatedSubject.name)
    }

    func testDELETE() async throws {
        
        let subjects: [Subject] = try await HTTP.GET(from: "\(serverPrefix)/subjects")
        let id = subjects.randomElement()!.id!
        try await HTTP.DELETE(via: "\(serverPrefix)/subjects/\(id)")
    }
}
