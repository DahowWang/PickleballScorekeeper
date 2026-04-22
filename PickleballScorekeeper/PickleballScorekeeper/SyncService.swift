import Foundation
import MultipeerConnectivity

protocol SyncServiceDelegate: AnyObject {
    func syncService(_ service: SyncService, didReceiveAction action: String, data: String)
    func syncService(_ service: SyncService, connectedDevicesChanged devices: [String])
}

class SyncService: NSObject {
    static let shared = SyncService()

    private let serviceType = "pkl-score"
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    weak var delegate: SyncServiceDelegate?
    var isActive = false

    private override init() {
        super.init()
        session = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        isActive = true
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        isActive = false
    }

    func sendAction(_ action: String, data: String) {
        guard !session.connectedPeers.isEmpty else { return }
        let message = "\(action)|\(data)"
        if let messageData = message.data(using: .utf8) {
            try? session.send(messageData, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    var connectedPeers: [MCPeerID] {
        session.connectedPeers
    }
}

extension SyncService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            let devices = session.connectedPeers.map { $0.displayName }
            self.delegate?.syncService(self, connectedDevicesChanged: devices)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8),
              let separatorIndex = message.firstIndex(of: "|") else { return }
        let action = String(message[message.startIndex..<separatorIndex])
        let payload = String(message[message.index(after: separatorIndex)...])
        DispatchQueue.main.async {
            self.delegate?.syncService(self, didReceiveAction: action, data: payload)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension SyncService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension SyncService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
