//
//  main.swift
//  http3ping
//
//  Created by Robin Senior on 2024-12-18.
//

import Foundation
import ArgumentParser

@main
struct Ping: AsyncParsableCommand {
	@Option(help: "The URL to send requests to") var url: String
	@Option(help: "Pause duration between requests in seconds") var pause: UInt32 = 1
	@Option(help: "Number of requests to send") var count: UInt32 = 1
	@Option(help: "Increment the pause length by this amount") var increment: UInt32 = 0
	@Option(help: "Keepalive period in seconds") var keepAlive: UInt16 = 0
	@Option(help: "Idle timeout in milliseconds") var idleTimeout: UInt32 = 600000

	mutating func validate() throws {
		guard count > 1 else {
			throw ValidationError("Count must be at least 1")
		}
	}

	mutating func run() async throws {
		let session: URLSession = {
			let config = URLSessionConfiguration.default
			config.requestCachePolicy = .reloadIgnoringLocalCacheData
			config.httpAdditionalHeaders = [
				"Alt-Svc": "clear" // This header clears any alternative protocol advertisements
			]

			return URLSession(configuration: config)
		}()

		let request = {
			var r = URLRequest(url: URL(string: url)!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
			r.assumesHTTP3Capable = true
			r.httpMethod = "GET"

			return r
		}()

		print("Sending \(count) requests to \(request.url!) with pause \(pause) and increment \(increment)")

		for i in (0..<count) {
			print("pinging \(request.url!)")

			do {
				let (_, response) = try await session.data(for: request)

				guard let httpResponse = response as? HTTPURLResponse else {
					throw URLError(.badServerResponse)
				}

				let now = Date.now
				print("\(now) Request \(i+1): \(httpResponse.statusCode)")

				if i < count - 1 {
					let durationInSeconds = UInt64(pause + i * increment)
					let durationInNanoseconds = durationInSeconds * 1_000_000_000

					print("Pausing for \(durationInSeconds) seconds")

					try await Task.sleep(nanoseconds: durationInNanoseconds)
				}
			} catch {
				print("Error making request: \(error)")
			}
		}
	}
}
