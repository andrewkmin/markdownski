import Foundation

public enum JSONProcessor {

    public enum Result {
        case success(String)
        case error(String)
    }

    public static func formatJSON(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error("Invalid JSON.\nInput is empty.")
        }
        do {
            let value = try parseValue(from: input)
            let formatted = try encode(value: value, pretty: true)
            return .success(formatted)
        } catch {
            return .error("Invalid JSON.\n\(error.localizedDescription)")
        }
    }

    public static func parseJSONString(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error("Input is empty.")
        }
        do {
            let inner = try decodeStringLiteral(from: input)
            let value: Any
            do {
                value = try parseValue(from: inner)
            } catch {
                return .error("String value does not contain valid JSON.\n\(error.localizedDescription)")
            }
            let formatted = try encode(value: value, pretty: true)
            return .success(formatted)
        } catch {
            return .error("\(error.localizedDescription)")
        }
    }

    public static func stringifyJSON(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error("Input is empty.")
        }
        do {
            let value = try parseValue(from: input)
            let canonical = try encode(value: value, pretty: false)
            let encoded = try JSONEncoder().encode(canonical)
            return .success(String(decoding: encoded, as: UTF8.self))
        } catch {
            return .error("Invalid JSON value.\n\(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private static func parseValue(from text: String) throws -> Any {
        let data = Data(text.utf8)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private static func encode(value: Any, pretty: Bool) throws -> String {
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .fragmentsAllowed]
        if pretty { options.insert(.prettyPrinted) }
        let data = try JSONSerialization.data(withJSONObject: value, options: options)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeStringLiteral(from text: String) throws -> String {
        let data = Data(text.utf8)
        do {
            return try JSONDecoder().decode(String.self, from: data)
        } catch {
            let summary = "Input must be a JSON string literal, for example: \"{\\\"name\\\":\\\"Ada\\\"}\""
            throw StringLiteralError(message: "\(summary)\n\(error.localizedDescription)")
        }
    }

    private struct StringLiteralError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
