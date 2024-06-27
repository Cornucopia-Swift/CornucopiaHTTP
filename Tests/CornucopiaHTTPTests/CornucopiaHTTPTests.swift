import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

let serverPrefix = "http://localhost:3000"

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
    
    func testGETtoURL() async throws {
        
        let url = URL(string: "https://www.google.de/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png")!
        let destination = URL(fileURLWithPath: "/tmp/\(UUID()).png")
        let headers = try await HTTP.GET(from: URLRequest(url: url), to: destination)
        print("file downloaded to \(destination), received headers: \(headers)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testGETtoURLwithProgress() async throws {
        let url = URL(string: "http://speedtest.ftp.otenet.gr/files/test10Mb.db")!
        let destination = URL(fileURLWithPath: "/tmp/\(UUID()).test10Mb.db")
        let headers = try await Networking().self.load(urlRequest: URLRequest(url: url), to: destination) { progress in
            print("file download progress: \(progress.fractionCompleted)")
        }
        print("file downloaded to \(destination), received headers: \(headers)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testBinaryPOST() async throws {
        let binary: [UInt8] = [0, 1, 2, 3, 4, 5]
        let data = Data(binary)
        let url = URL(string: "http://www.foo.bar.baz/testing")!
        try await HTTP.POST(data: data, via: URLRequest(url: url))
    }
    
    func testCompressedUpload() async throws {
        
        // TBD
    }
}
