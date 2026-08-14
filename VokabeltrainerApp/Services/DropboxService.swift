import Foundation

/// Minimal Dropbox HTTP API v2 client used to keep word lists in sync across devices.
/// Authenticates with a long-lived (or scoped) access token generated in the Dropbox
/// App Console — pasted once in Settings — rather than a full OAuth dance, which keeps
/// setup to a single copy/paste for a personal single-user app.
actor DropboxService {
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func upload(content: String, remotePath: String) async throws {
        var request = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/upload")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let args: [String: Any] = [
            "path": remotePath, "mode": "overwrite", "autorename": false, "mute": true,
        ]
        request.setValue(try Self.headerJSON(args), forHTTPHeaderField: "Dropbox-API-Arg")
        request.httpBody = content.data(using: .utf8)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response, data: data)
    }

    func download(remotePath: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/download")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(try Self.headerJSON(["path": remotePath]), forHTTPHeaderField: "Dropbox-API-Arg")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response, data: data)
        guard let text = String(data: data, encoding: .utf8) else { throw DropboxError.decodingFailed }
        return text
    }

    /// Returns the file names (not full paths) directly inside `path`.
    /// Returns an empty list — rather than throwing — if the folder doesn't exist yet;
    /// it will be created automatically on the first upload.
    func listFolder(path: String) async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.dropboxapi.com/2/files/list_folder")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["path": path])
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 409 {
            return []
        }
        try Self.checkResponse(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entries"] as? [[String: Any]] else { return [] }
        return entries.compactMap { $0["name"] as? String }
    }

    // MARK: - Private

    private static func headerJSON(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let str = String(data: data, encoding: .utf8) else { throw DropboxError.decodingFailed }
        return str
    }

    private static func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw DropboxError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DropboxError.apiError(message)
        }
    }
}

enum DropboxError: LocalizedError {
    case invalidResponse
    case decodingFailed
    case apiError(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Dropbox."
        case .decodingFailed: return "Could not decode Dropbox response."
        case .apiError(let msg): return "Dropbox error: \(msg)"
        case .notConnected: return "Dropbox is not connected yet."
        }
    }
}
