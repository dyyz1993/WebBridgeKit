//
//  NetworkHelper.swift
//  WebBridgeKit
//
//  Created by WebBridgeKit
//

import Foundation

/// Network request utility class with timeout configuration
public final class NetworkHelper {

    // MARK: - Singleton

    public static let shared = NetworkHelper()

    private init() {}

    // MARK: - Properties

    /// URLSession with configured timeout settings
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 30.0
        return URLSession(configuration: configuration)
    }()

    // MARK: - Public Methods

    /// Fetches data from the specified URL
    /// - Parameter url: The URL to fetch data from
    /// - Returns: The data retrieved from the URL
    /// - Throws: `WebBridgeError.networkRequestFailed` if the request fails
    public func fetch(url: URL) async throws -> Data {
        Log.debug("Starting network request to: \(url.absoluteString)", category: .network)

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                let error = WebBridgeError.networkRequestFailed(reason: "Invalid response type")
                Log.error("Network request failed: Invalid response type", category: .network)
                throw error
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let error = WebBridgeError.networkRequestFailed(reason: "HTTP status code: \(httpResponse.statusCode)")
                Log.error("Network request failed: HTTP status code \(httpResponse.statusCode)", category: .network)
                throw error
            }

            Log.info("Network request succeeded: \(data.count) bytes received", category: .network)
            return data

        } catch let urlError as URLError {
            let webBridgeError = WebBridgeError.networkRequestFailed(reason: urlError.localizedDescription)
            Log.error("Network request failed: \(urlError.localizedDescription)", category: .network)
            throw webBridgeError

        } catch let webBridgeError as WebBridgeError {
            throw webBridgeError

        } catch {
            let webBridgeError = WebBridgeError.networkRequestFailed(reason: error.localizedDescription)
            Log.error("Network request failed with unexpected error: \(error.localizedDescription)", category: .network)
            throw webBridgeError
        }
    }
}
