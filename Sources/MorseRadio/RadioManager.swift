import Foundation
import MultipeerConnectivity
import Combine

private struct MorsePacket: Codable {
    let action: String
    let sender: String
}

final class RadioManager: NSObject, ObservableObject {
    @Published private(set) var frequency: String
    @Published private(set) var peerNames: [String] = []
    @Published private(set) var isSending = false

    private let serviceType = "morse-radio"
    private let tone = MorseTonePlayer()
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invitedPeers = Set<MCPeerID>()
    private var localKeyIsDown = false

    override init() {
        let saved = UserDefaults.standard.string(forKey: "radio.frequency") ?? "145.500"
        frequency = Self.normalizedFrequency(saved) ?? "145.500"
        super.init()
        peerID = makePeerID()
        createSession()
        startDiscovery()
    }

    @discardableResult
    func setFrequency(_ input: String) -> Bool {
        guard let value = Self.normalizedFrequency(input) else { return false }
        guard value != frequency else { return true }
        endLocalKey()
        tone.releaseAll()
        frequency = value
        UserDefaults.standard.set(value, forKey: "radio.frequency")
        startDiscovery()
        return true
    }

    func beginLocalKey() {
        guard !localKeyIsDown else { return }
        localKeyIsDown = true
        isSending = true
        tone.keyDown(from: "local")
        send(action: "down", sender: peerID.displayName)
    }

    func endLocalKey() {
        guard localKeyIsDown else { return }
        localKeyIsDown = false
        isSending = false
        tone.keyUp(from: "local")
        send(action: "up", sender: peerID.displayName)
    }

    private static func normalizedFrequency(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard (1...24).contains(value.count),
              value.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_").contains($0)
              }) else { return nil }
        return value
    }

    private func makePeerID() -> MCPeerID {
        let host = Host.current().localizedName ?? "Mac"
        let suffix = String(UUID().uuidString.prefix(5))
        return MCPeerID(displayName: String("\(host)-\(suffix)".prefix(63)))
    }

    private func createSession() {
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    private func startDiscovery() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        tone.releaseAll()
        invitedPeers.removeAll()
        peerNames = []
        createSession()

        let info = ["frequency": frequency]
        let newAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: serviceType)
        newAdvertiser.delegate = self
        advertiser = newAdvertiser
        newAdvertiser.startAdvertisingPeer()

        let newBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        newBrowser.delegate = self
        browser = newBrowser
        newBrowser.startBrowsingForPeers()
    }

    private func send(action: String, sender: String) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(MorsePacket(action: action, sender: sender)) else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            NSLog("Morse Radio could not send a key event: %@", error.localizedDescription)
        }
    }
}

extension RadioManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("Morse Radio advertising failed: %@", error.localizedDescription)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Only accept invitations for the currently selected virtual frequency.
        invitationHandler(true, session)
    }
}

extension RadioManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("Morse Radio browsing failed: %@", error.localizedDescription)
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?["frequency"] == frequency,
              peerID != self.peerID,
              !invitedPeers.contains(peerID) else { return }
        invitedPeers.insert(peerID)
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        invitedPeers.remove(peerID)
    }
}

extension RadioManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if state != .connected {
                self.tone.keyUp(from: peerID.displayName)
            }
            self.peerNames = session.connectedPeers.map(\.displayName).sorted()
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let packet = try? JSONDecoder().decode(MorsePacket.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch packet.action {
            case "down": self.tone.keyDown(from: peerID.displayName)
            case "up": self.tone.keyUp(from: peerID.displayName)
            default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
