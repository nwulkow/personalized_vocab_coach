import CryptoKit
import Foundation

/// One-time Dropbox authorization using OAuth 2 **PKCE** with `token_access_type=offline`.
///
/// Why this instead of pasting the App Console's "Generated access token": that token is
/// short-lived (`sl.…`, ~4 hours) and long-lived tokens have been deprecated since 2021.
/// PKCE yields a **refresh token**, which does not expire — so you authorize once and the app
/// silently mints fresh access tokens forever after.
///
/// PKCE also means no app secret has to be stored on the phone, and omitting `redirect_uri`
/// makes Dropbox display the authorization code on screen for copy/paste — so nothing has to
/// be registered under "Redirect URIs" in the App Console.
enum DropboxAuth {

    struct PKCE {
        let verifier: String
        let challenge: String
    }

    struct Tokens {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval
    }

    // MARK: - PKCE

    static func makePKCE() -> PKCE {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = base64URL(Data(bytes))
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return PKCE(verifier: verifier, challenge: base64URL(Data(digest)))
    }

    static func authorizeURL(appKey: String, challenge: String) -> URL? {
        var components = URLComponents(string: "https://www.dropbox.com/oauth2/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: appKey),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            // "offline" is what makes Dropbox return a refresh token at all.
            URLQueryItem(name: "token_access_type", value: "offline"),
        ]
        return components?.url
    }

    // MARK: - Token endpoint

    /// Trades the pasted authorization code for an access token + a non-expiring refresh token.
    static func exchange(code: String, verifier: String, appKey: String) async throws -> Tokens {
        try await tokenRequest([
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "grant_type": "authorization_code",
            "code_verifier": verifier,
            "client_id": appKey,
        ])
    }

    /// Mints a fresh short-lived access token from the stored refresh token.
    static func refresh(refreshToken: String, appKey: String) async throws -> Tokens {
        try await tokenRequest([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": appKey,
        ])
    }

    private static func tokenRequest(_ fields: [String: String]) async throws -> Tokens {
        var request = URLRequest(url: URL(string: "https://api.dropboxapi.com/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = formEncode(fields).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DropboxError.invalidResponse }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DropboxError.decodingFailed
        }
        guard (200...299).contains(http.statusCode) else {
            let detail = (json["error_description"] as? String)
                ?? (json["error"] as? String)
                ?? "HTTP \(http.statusCode)"
            throw DropboxError.apiError(detail)
        }
        guard let accessToken = json["access_token"] as? String else { throw DropboxError.decodingFailed }
        return Tokens(
            accessToken: accessToken,
            refreshToken: json["refresh_token"] as? String,
            expiresIn: (json["expires_in"] as? Double) ?? 14400
        )
    }

    // MARK: - Encoding helpers

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields.map { key, value in
            let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encoded)"
        }
        .joined(separator: "&")
    }
}
