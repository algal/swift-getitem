import XCTest

// Assuming the main getitem functionality is in a module or can be accessed within this test file.
// If the functions are in another module, you may need to import it accordingly.

// Helper functions and struct definitions (these should match the implementations in your main code)

// MARK: - SliceSpec
struct SliceSpec {
    var start: Int?
    var end: Int?
}

// MARK: - Tests Class
final class GetitemTests: XCTestCase {

    // Helper function equivalent to Python's f and Rust's strip_first_newline
    func stripFirstNewline(_ s: String) -> String {
        if s.hasPrefix("\n") {
            return String(s.dropFirst())
        } else {
            return s
        }
    }

    // Helper function to prepare test cases
    func prepareTestCase(input: String, rowSpec: String, colSpec: String, expected: String) -> (String, (String, String), String) {
        let inputTrimmed = stripFirstNewline(input)
        let expectedTrimmed = stripFirstNewline(expected)
        return (inputTrimmed, (rowSpec, colSpec), expectedTrimmed)
    }

    // Implement the necessary functions (sliceFromSpec, splitWithPositions, filteredLine, islice, normalizeIndices)

    // MARK: - Parsing Slice Specification
    func sliceFromSpec(_ sliceSpec: String) -> SliceSpec? {
        if sliceSpec.contains(":") {
            let parts = sliceSpec.split(separator: ":").map { String($0) }
            let startPart = parts.count > 0 ? parts[0] : ""
            let endPart = parts.count > 1 ? parts[1] : ""

            let start = startPart.isEmpty ? nil : Int(startPart)
            let end = endPart.isEmpty ? nil : Int(endPart)

            return SliceSpec(start: start, end: end)
        } else {
            if let pos = Int(sliceSpec) {
                if pos == -1 {
                    return SliceSpec(start: pos, end: nil)
                } else {
                    return SliceSpec(start: pos, end: pos + 1)
                }
            } else {
                return nil
            }
        }
    }

    // MARK: - Split with Positions
    struct SplitResult {
        var text: String
        var start: Int
        var end: Int
    }

    func splitWithPositions(_ strToSplit: String, pattern: String) -> [SplitResult] {
        var results: [SplitResult] = []
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsStr = strToSplit as NSString
        var lastEnd = 0

        regex.enumerateMatches(in: strToSplit, options: [], range: NSRange(location: 0, length: nsStr.length)) { match, _, _ in
            guard let match = match else { return }
            let start = match.range.location
            if start > lastEnd {
                let substring = nsStr.substring(with: NSRange(location: lastEnd, length: start - lastEnd))
                results.append(SplitResult(text: substring, start: lastEnd, end: start))
            }
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsStr.length {
            let substring = nsStr.substring(from: lastEnd)
            results.append(SplitResult(text: substring, start: lastEnd, end: nsStr.length))
        }

        return results
    }

    // MARK: - Filtered Line
    func filteredLine(line: String, colSlice: SliceSpec) -> String? {
        let eolToPreserve = line.hasSuffix("\n") ? "\n" : ""
        let fields = splitWithPositions(line, pattern: "\\s+")

        let totalFields = fields.count
        let startIdx: Int
        if let start = colSlice.start {
            startIdx = start >= 0 ? start : totalFields + start
        } else {
            startIdx = 0
        }

        let endIdx: Int
        if let end = colSlice.end {
            endIdx = end >= 0 ? end : totalFields + end
        } else {
            endIdx = fields.count
        }

        guard startIdx >= 0, startIdx < fields.count, startIdx < endIdx else {
            return nil
        }

        let slicedFields = fields[startIdx..<min(endIdx, fields.count)]
        if slicedFields.isEmpty {
            return nil
        }

        let startPos = slicedFields.first!.start
        let endPos = slicedFields.last!.end

        let prefixSpaces = String(repeating: " ", count: startPos)
        let contentStart = line.index(line.startIndex, offsetBy: startPos)
        let contentEnd = line.index(line.startIndex, offsetBy: endPos)
        let content = String(line[contentStart..<contentEnd])

        return prefixSpaces + content + eolToPreserve
    }

    // MARK: - ISlice Function
    func islice<T>(lines: [T], slice: SliceSpec, iterableLength: Int?) -> [T] {
        let needLength = (slice.start ?? 0) < 0 || (slice.end ?? 0) < 0

        let length = iterableLength ?? lines.count

        let (normalizedStart, normalizedEnd) = normalizeIndices(start: slice.start ?? 0, end: slice.end, length: needLength ? length : nil)

        guard normalizedStart >= 0 else { return [] }

        let endIndex = normalizedEnd ?? lines.count
        guard normalizedStart < endIndex else { return [] }

        let slicedLines = Array(lines[normalizedStart..<min(endIndex, lines.count)])
        return slicedLines
    }

    // MARK: - Normalize Indices
    func normalizeIndices(start: Int, end: Int?, length: Int?) -> (Int, Int?) {
        guard let length = length else {
            return (start, end)
        }

        let normalizedStart = start >= 0 ? start : length + start
        let normalizedEnd = end.map { $0 >= 0 ? $0 : length + $0 }

        return (normalizedStart, normalizedEnd)
    }

    // MARK: - Pick Function
    func pick(lines: [String], rowSpec: String, colSpec: String, lineCount: Int?) -> [String] {
        guard let rowSliceSpec = sliceFromSpec(rowSpec),
              let colSliceSpec = sliceFromSpec(colSpec) else {
            return []
        }

        let slicedLines = islice(lines: lines, slice: rowSliceSpec, iterableLength: lineCount)
        var resultLines: [String] = []

        for line in slicedLines {
            if let outputLine = filteredLine(line: line, colSlice: colSliceSpec) {
                resultLines.append(outputLine)
            }
        }

        return resultLines
    }

    // MARK: - Test Cases

    func test_case_s0() {
        let input = """
        On branch dev-longcontexteval
        Your branch is up to date with 'origin/dev-longcontexteval'.

        Untracked files:
          (use "git add <file>..." to include in what will be committed)
            bert24-base-v2.yaml
            r_first50000.json
            src/evals/items2000.json
            src/evals/rewritten10.json

        nothing added to commit but untracked files present (use "git add" to track)
        """

        let expected = """
            bert24-base-v2.yaml
            r_first50000.json
            src/evals/items2000.json
            src/evals/rewritten10.json
        """

        let (inputString, (rowSpec, colSpec), expectedString) = prepareTestCase(
            input: input,
            rowSpec: "5:-2",
            colSpec: ":",
            expected: expected
        )

        let lines = inputString.components(separatedBy: .newlines)
        let lineCount = lines.count

        let actualLines = pick(lines: lines, rowSpec: rowSpec, colSpec: colSpec, lineCount: lineCount)

        let expectedLines = expectedString.components(separatedBy: .newlines)

        XCTAssertEqual(actualLines, expectedLines)
    }

    func test_case_s1() {
        let input = """
        AAA
         BBB
        CCC
        """

        let expected = """
         BBB
        """

        let (inputString, (rowSpec, colSpec), expectedString) = prepareTestCase(
            input: input,
            rowSpec: "1",
            colSpec: ":",
            expected: expected
        )

        let lines = inputString.components(separatedBy: .newlines)
        let lineCount = lines.count

        let actualLines = pick(lines: lines, rowSpec: rowSpec, colSpec: colSpec, lineCount: lineCount)
        let expectedLines = expectedString.components(separatedBy: .newlines)

        XCTAssertEqual(actualLines, expectedLines)
    }

    func test_case_s2() {
        let dirstring = """
        .rw-r--r-- 0 root      2024-11-14 20:59 .localized
        drwxr-x--- - alexis    2024-11-25 16:29 alexis
        drwxr-xr-x - oldalexis 2023-09-17 14:13 alexis_1
        drwxrwxrwt - root      2024-11-21 12:25 Shared
        """

        let expected = dirstring

        let (inputString, (rowSpec, colSpec), expectedString) = prepareTestCase(
            input: dirstring,
            rowSpec: ":",
            colSpec: ":",
            expected: expected
        )

        let lines = inputString.components(separatedBy: .newlines)
        let lineCount = lines.count

        let actualLines = pick(lines: lines, rowSpec: rowSpec, colSpec: colSpec, lineCount: lineCount)
        let expectedLines = expectedString.components(separatedBy: .newlines)

        XCTAssertEqual(actualLines, expectedLines)
    }

    func test_case_s3() {
        let dirstring = """
        .rw-r--r-- 0 root      2024-11-14 20:59 .localized
        drwxr-x--- - alexis    2024-11-25 16:29 alexis
        drwxr-xr-x - oldalexis 2023-09-17 14:13 alexis_1
        drwxrwxrwt - root      2024-11-21 12:25 Shared
        """

        let expected = """
        .rw-r--r-- 0 root      2024-11-14 20:59 .localized
        drwxr-x--- - alexis    2024-11-25 16:29 alexis
        """

        let (inputString, (rowSpec, colSpec), expectedString) = prepareTestCase(
            input: dirstring,
            rowSpec: "0:2",
            colSpec: ":",
            expected: expected
        )

        let lines = inputString.components(separatedBy: .newlines)
        let lineCount = lines.count

        let actualLines = pick(lines: lines, rowSpec: rowSpec, colSpec: colSpec, lineCount: lineCount)
        let expectedLines = expectedString.components(separatedBy: .newlines)

        XCTAssertEqual(actualLines, expectedLines)
    }

    func test_case_s4() {
        let dirstring = """
        .rw-r--r-- 0 root      2024-11-14 20:59 .localized
        drwxr-x--- - alexis    2024-11-25 16:29 alexis
        drwxr-xr-x - oldalexis 2023-09-17 14:13 alexis_1
        drwxrwxrwt - root      2024-11-21 12:25 Shared
        """

        let expected = """
        drwxr-xr-x - oldalexis 2023-09-17 14:13 alexis_1
        drwxrwxrwt - root      2024-11-21 12:25 Shared
        """

        let (inputString, (rowSpec, colSpec), expectedString) = prepareTestCase(
            input: dirstring,
            rowSpec: "-2:",
            colSpec: ":",
            expected: expected
        )

        let lines = inputString.components(separatedBy: .newlines)
        let lineCount = lines.count

        let actualLines = pick(lines: lines, rowSpec: rowSpec, colSpec: colSpec, lineCount: lineCount)
        let expectedLines = expectedString.components(separatedBy: .newlines)

        XCTAssertEqual(actualLines, expectedLines)
    }

    func test_case_s5() {
        let dirstring = """
        .rw-r--r-- 0 root      2024-11-14 20:59 .localized
        drwxr-x--- - alexis    2024-11-25 16:29 alexis
        drwxr-xr-x - oldalexis 2023-09-17 14:13 alexis_1
        drwxrwxrwt - root      2024-11-21 12:25 Shared
        """

        let expected = """
                               2023-09-17 14:13
        """

        let (inputString, (rowSpec, colSpec), expectedString) = prepareTestCase(
            input: dirstring,
            rowSpec: "-2",
            colSpec: "-3:-1",
            expected: expected
        )

        let lines = inputString.components(separatedBy: .newlines)
        let lineCount = lines.count

        let actualLines = pick(lines: lines, rowSpec: rowSpec, colSpec: colSpec, lineCount: lineCount)
        let expectedLines = expectedString.components(separatedBy: .newlines)

        XCTAssertEqual(actualLines, expectedLines)
    }

    func test_case_s6() {
        let input = """
        #!/bin/bash
        if [ "$#" -ne 2 ]; then
            echo "usage: make-linkfile.bash HTTP-URL TITLE"
            echo
            echo "To find links to nightlies, go to https://github.com/tensorflow/swift/blob/master/Installation.md "
            echo
            echo "A valid URL will look something like: https://storage.googleapis.com/swift-tensorflow-artifacts/releases/v0.3/rc1/swift-tensorflow-RELEASE-0.3-cuda10.0-cudnn7-ubuntu18.04.tar.gz"
            exit 1
        else
            url="$1"
            title="$2"
        fi

        cat <<EOF > "${title}.html"
        <!DOCTYPE html><html>
          <head><title>Redirecting to: ${url}</title>
          <meta http-equiv = "refresh" content = "0;url='${url}'" />
        </head></html>
        EOF

        echo "Created file $(readlink -f "${title}.html")"
        """

        let expected = """
        if [ "$#" -ne 2 ]; then
            echo "usage: make-linkfile.bash HTTP-URL TITLE"
            echo
            echo "To find links to nightlies, go to https://github.com/tensorflow/swift/blob/master/Installation.md "
            echo
            echo "A valid URL will look something like: https://storage.googleapis.com/swift-tensorflow-artifacts/releases/v0.3/rc1/swift-tensorflow-RELEASE-0.3-cuda10.0-cudnn7-ubuntu18.04.tar.gz"
            exit 1
        else
            url="$1"
        """

        let (inputString, (rowSpec, colSpec), expectedString) = prepareTestCase(
            input: input,
            rowSpec: "1:10",
            colSpec: ":",
            expected: expected
        )

        let lines = inputString.components(separatedBy: .newlines)
        let lineCount = lines.count

        let actualLines = pick(lines: lines, rowSpec: rowSpec, colSpec: colSpec, lineCount: lineCount)
        let expectedLines = expectedString.components(separatedBy: .newlines)

        XCTAssertEqual(actualLines, expectedLines)
    }
}
