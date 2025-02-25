#!/usr/bin/env swift

import Foundation

// MARK: - SliceSpec
struct SliceSpec {
    var start: Int?
    var end: Int?
}

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
    let regex = try! Regex(pattern)
    var lastEnd = strToSplit.startIndex

    for match in strToSplit.matches(of: regex) {
        let start = match.range.lowerBound
        if start > lastEnd {
            let substring = String(strToSplit[lastEnd..<start])
            results.append(SplitResult(text: substring, start: strToSplit.distance(from: strToSplit.startIndex, to: lastEnd), end: strToSplit.distance(from: strToSplit.startIndex, to: start)))
        }
        lastEnd = match.range.upperBound
    }

    if lastEnd < strToSplit.endIndex {
        let substring = String(strToSplit[lastEnd...])
        results.append(SplitResult(text: substring, start: strToSplit.distance(from: strToSplit.startIndex, to: lastEnd), end: strToSplit.count))
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
    let content = String(line[line.index(line.startIndex, offsetBy: startPos)..<line.index(line.startIndex, offsetBy: endPos)])
    return prefixSpaces + content + eolToPreserve
}

// MARK: - ISlice Iterator
class ISlice<T: IteratorProtocol>: IteratorProtocol where T.Element == String {
    var source: T
    var buffer: [(Int, String)]?
    var start: Int
    var end: Int?
    var index: Int = 0
    var length: Int?
    
    init(source: T, slice: SliceSpec, iterableLength: Int?) {
        self.source = source
        self.length = iterableLength
        
        let needLength = (slice.start ?? 0) < 0 || (slice.end ?? 0) < 0
        
        if needLength && iterableLength == nil {
            // Buffer the entire source to determine length
            buffer = []
            var i = 0
            while let line = self.source.next() {
                buffer?.append((i, line))
                i += 1
            }
            self.length = i
        }
        
        let (normalizedStart, normalizedEnd) = normalizeIndices(start: slice.start ?? 0, end: slice.end, length: self.length)
        self.start = normalizedStart
        self.end = normalizedEnd
    }
    
    func next() -> String? {
        if let buffer = buffer {
            while index < buffer.count {
                let (i, line) = buffer[index]
                index += 1
                if i >= start && (end == nil || i < end!) {
                    return line
                }
            }
            return nil
        } else {
            while let line = source.next() {
                let currentIdx = index
                index += 1
                if currentIdx >= start && (end == nil || currentIdx < end!) {
                    return line
                }
            }
            return nil
        }
    }
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

// MARK: - Command-Line Parsing
enum OptionType: String {
    case help = "-h"
    case helpLong = "--help"
    case file = "-f"
    case fileLong = "--file"
}

struct CommandLineOptions {
    var inputFile: String?
    var rowSpec: String?
    var colSpec: String?
}

func parseCommandLine() -> CommandLineOptions? {
    var options = CommandLineOptions()
    var args = CommandLine.arguments.dropFirst()
    
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case OptionType.help.rawValue, OptionType.helpLong.rawValue:
            printUsage()
            exit(0)
        case OptionType.file.rawValue, OptionType.fileLong.rawValue:
            if let nextArg = args.first {
                options.inputFile = nextArg
                args = args.dropFirst()
            } else {
                print("Error: \(arg) requires a value")
                exit(2)
            }
        default:
            if options.rowSpec == nil {
                options.rowSpec = arg
            } else if options.colSpec == nil {
                options.colSpec = arg
            } else {
                print("Error: Unexpected argument \(arg)")
                exit(1)
            }
        }
    }
    
    if options.rowSpec == nil || options.colSpec == nil {
        printUsage()
        exit(1)
    }
    
    return options
}


// MARK: - Usage
func printUsage() {
    let usage = """
    Usage: getitem [-h] [-f FILE] row_spec col_spec

    Filter stdin and print specific rows and columns, specifying
    them in Python's slicing syntax, separating columns by whitespace.

    If passed FILE, it will read the file twice but not buffer.

    For example:
    cat myfile | getitem :5 0     # Print the column 0 of the first 5 rows.
    cat myfile | getitem 0 :      # Print the first row, all of it.
    cat myfile | getitem -10 0:2  # Print the first 2 columns of the last 10 rows.
    cat myfile | getitem -2:-1 :  # Prints all fields of the second to last row.
    """
    print(usage)
}

// MARK: - Main Functionality
func main() {
    guard let options = parseCommandLine() else { return }
    
    guard let rowSpecString = options.rowSpec, let colSpecString = options.colSpec else {
        print("Error: Missing row_spec or col_spec")
        exit(1)
    }
    
    guard let rowSliceSpec = sliceFromSpec(rowSpecString),
          let colSliceSpec = sliceFromSpec(colSpecString) else {
        print("Error: Invalid slice specification")
        exit(1)
    }
    
    let lines: AnySequence<String>
    var lineCount: Int? = nil
    
    if let inputFile = options.inputFile {
        guard let fileData = try? String(contentsOfFile: inputFile, encoding: .utf8) else {
            print("Error: Could not read file \(inputFile)")
            exit(1)
        }
        let fileLines = fileData.split(separator: "\n", omittingEmptySubsequences: false).map { "\($0)\n" }
        lines = AnySequence(fileLines)
        lineCount = fileLines.count
    } else {
        let stdinFileHandle = FileHandle.standardInput
        let stdinData = stdinFileHandle.readDataToEndOfFile()
        guard let stdinString = String(data: stdinData, encoding: .utf8) else {
            print("Error: Could not read from stdin")
            exit(1)
        }
        let stdinLines = stdinString.split(separator: "\n", omittingEmptySubsequences: false).map { "\($0)\n" }
        lines = AnySequence(stdinLines)
    }
    
    let lineIterator = lines.makeIterator()
    let islice = ISlice(source: lineIterator, slice: rowSliceSpec, iterableLength: lineCount)
    
    while let line = islice.next() {
        if let outputLine = filteredLine(line: line, colSlice: colSliceSpec) {
            print(outputLine, terminator: "")
        }
    }
}

main()
