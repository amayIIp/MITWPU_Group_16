//
//  NetworkMonitor.swift
//  Stuttering App
//
//  Lightweight network reachability monitor.
//  InsightEngine checks this before attempting any Groq API call
//  so that offline users fall through to rule-based insights
//  instantly rather than waiting up to 44 seconds for retries to exhaust.
//

import Foundation
import Network

final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "com.spasht.networkmonitor", qos: .utility)

    /// `true` when the device has any usable network path (Wi-Fi, cellular, etc.)
    private(set) var isConnected: Bool = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = (path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
