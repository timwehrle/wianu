import Foundation

nonisolated enum CSVParser {
    enum ParseError: Error {
        case unterminatedQuotedField
    }

    static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\"" {
                let nextIndex = text.index(after: index)

                if isInsideQuotes,
                   nextIndex < text.endIndex,
                   text[nextIndex] == "\""
                {
                    field.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",", !isInsideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n"
                || character == "\r"
                || character == "\r\n",
                !isInsideQuotes
            {
                row.append(field)
                field = ""

                if row.contains(where: { !$0.isEmpty }) {
                    rows.append(row)
                }

                row = []

                if character == "\r" {
                    let nextIndex = text.index(after: index)

                    if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                        index = nextIndex
                    }
                }
            } else {
                field.append(character)
            }

            index = text.index(after: index)
        }

        guard !isInsideQuotes else {
            throw ParseError.unterminatedQuotedField
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}
