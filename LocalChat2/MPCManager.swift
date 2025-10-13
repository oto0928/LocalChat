import Foundation
import MultipeerConnectivity
import SwiftUI

// MARK: - MPCManager
class MPCManager: NSObject, ObservableObject {
    static let shared = MPCManager()
    
    // MARK: - Properties
    @Published var isHosting = false
    @Published var isBrowsing = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var displayName: String = UIDevice.current.name
    
    private let serviceType = "p2p-play"
    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // MARK: - Callbacks
    var onReceiveData: ((Data, MCPeerID) -> Void)?
    var onStateChange: (() -> Void)?
    
    // MARK: - Initialization
    override init() {
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        
        super.init()
        
        session.delegate = self
    }
    
    // MARK: - Host Methods
    func startHosting() {
        stopAllServices()
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        isHosting = true
        connectionState = .hosting
        onStateChange?()
    }
    
    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isHosting = false
        
        if connectedPeers.isEmpty {
            connectionState = .disconnected
        }
        onStateChange?()
    }
    
    // MARK: - Guest Methods
    func startBrowsing() {
        stopAllServices()
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        isBrowsing = true
        connectionState = .browsing
        onStateChange?()
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
        
        if connectedPeers.isEmpty {
            connectionState = .disconnected
        }
        onStateChange?()
    }
    
    // MARK: - Connection Methods
    func invite(peer: MCPeerID) {
        guard let browser = browser else { return }
        
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    func disconnect() {
        stopAllServices()
        session.disconnect()
        connectedPeers.removeAll()
        discoveredPeers.removeAll()
        connectionState = .disconnected
        onStateChange?()
    }
    
    // MARK: - Data Transmission
    func send(data: Data, reliably: Bool = true) {
        guard !connectedPeers.isEmpty else { return }
        
        do {
            try session.send(data, toPeers: connectedPeers, with: reliably ? .reliable : .unreliable)
        } catch {
            print("Failed to send data: \(error)")
        }
    }
    
    func sendToPeer(data: Data, peer: MCPeerID, reliably: Bool = true) {
        do {
            try session.send(data, toPeers: [peer], with: reliably ? .reliable : .unreliable)
        } catch {
            print("Failed to send data to peer: \(error)")
        }
    }
    
    // MARK: - Private Methods
    private func stopAllServices() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        isHosting = false
        isBrowsing = false
    }
}

// MARK: - MCSessionDelegate
extension MPCManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.connectionState = .connected
                
            case .connecting:
                self.connectionState = .connecting
                
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                self.discoveredPeers.removeAll { $0 == peerID }
                
                if self.connectedPeers.isEmpty {
                    self.connectionState = self.isHosting ? .hosting : (self.isBrowsing ? .browsing : .disconnected)
                }
                
            @unknown default:
                break
            }
            
            self.onStateChange?()
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.onReceiveData?(data, peerID)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used in this implementation
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used in this implementation
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used in this implementation
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MPCManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            invitationHandler(true, self.session)
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            print("Failed to start advertising: \(error)")
            self.isHosting = false
            self.connectionState = .disconnected
            self.onStateChange?()
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MPCManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            print("Failed to start browsing: \(error)")
            self.isBrowsing = false
            self.connectionState = .disconnected
            self.onStateChange?()
        }
    }
}

// MARK: - ConnectionState
enum ConnectionState {
    case disconnected
    case hosting
    case browsing
    case connecting
    case connected
    
    var description: String {
        switch self {
        case .disconnected:
            return "未接続"
        case .hosting:
            return "ホスト中"
        case .browsing:
            return "検索中"
        case .connecting:
            return "接続中"
        case .connected:
            return "接続済み"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected:
            return .gray
        case .hosting:
            return .blue
        case .browsing:
            return .orange
        case .connecting:
            return .yellow
        case .connected:
            return .green
        }
    }
}
