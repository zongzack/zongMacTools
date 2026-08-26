import Foundation
import XCTest
import FinderNewFileCore

final class FinderOfficeTemplateTests: XCTestCase {
    func testOfficeArchivesContainRequiredOpenXMLParts() throws {
        try assertArchive(
            format: .word,
            requiredEntries: ["[Content_Types].xml", "_rels/.rels", "word/document.xml"],
            xmlChecks: [("word/document.xml", "<w:document"), ("_rels/.rels", "officeDocument")]
        )
        try assertArchive(
            format: .excel,
            requiredEntries: ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels", "xl/worksheets/sheet1.xml"],
            xmlChecks: [("xl/workbook.xml", "name=\"Sheet1\""), ("xl/worksheets/sheet1.xml", "<sheetData")]
        )
        try assertArchive(
            format: .powerpoint,
            requiredEntries: ["[Content_Types].xml", "_rels/.rels", "ppt/presentation.xml", "ppt/_rels/presentation.xml.rels", "ppt/slides/slide1.xml"],
            xmlChecks: [("ppt/presentation.xml", "<p:presentation"), ("ppt/slides/slide1.xml", "<p:sld")]
        )
    }

    private func assertArchive(
        format: FinderNewFileFormat,
        requiredEntries: [String],
        xmlChecks: [(String, String)]
    ) throws {
        let archiveURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(format.rawValue)-\(UUID().uuidString).zip")
        try FinderOfficeTemplateProvider.data(for: format).write(to: archiveURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let entries = try runUnzip(arguments: ["-Z1", archiveURL.path]).split(separator: "\n").map(String.init)
        for entry in requiredEntries {
            XCTAssertTrue(entries.contains(entry), "missing OOXML entry \(entry) in \(format.rawValue)")
        }
        for (entry, expectedText) in xmlChecks {
            let xml = try runUnzip(arguments: ["-p", archiveURL.path, entry])
            XCTAssertTrue(xml.contains(expectedText), "\(entry) did not contain \(expectedText)")
        }
    }

    private func runUnzip(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "FinderOfficeTemplateTests", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: text])
        }
        return text
    }
}
