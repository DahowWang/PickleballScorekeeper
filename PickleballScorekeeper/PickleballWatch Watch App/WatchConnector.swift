import Foundation
import WatchConnectivity

class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()

    @Published var isConnected = false
    @Published var scoreLeft = 0
    @Published var scoreRight = 0
    @Published var playersLeft: [String] = ["P1", "P2"]
    @Published var playersRight: [String] = ["P3", "P4"]
    @Published var serving: String = "left"
    @Published var server: Int = 2
    @Published var gameMode: String = "doubles"
    @Published var swapL = false
    @Published var swapR = false
    @Published var isFirstServer = false
    @Published var serverOneIsAltLeft = false
    @Published var serverOneIsAltRight = false

    // Mirrors HTML getServeSlot(): returns 0 or 1 within the team
    func servingPlayerIndex(side: String) -> Int {
        let swapped = (side == "left") ? swapL : swapR
        let altFlag = (side == "left") ? serverOneIsAltLeft : serverOneIsAltRight
        let pMain = swapped ? 1 : 0
        let pAlt  = swapped ? 0 : 1
        let s1pos = altFlag ? pAlt : pMain
        let s2pos = altFlag ? pMain : pAlt
        return server == 1 ? s1pos : s2pos
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // Display order: accounts for position swaps after scoring
    func displayPlayers(side: String) -> [String] {
        let players = (side == "left") ? playersLeft : playersRight
        let swapped = (side == "left") ? swapL : swapR
        return swapped ? players.reversed() : players
    }

    func addPoint(side: String) {
        if side != serving {
            fault()
            return
        }
        if side == "left" {
            scoreLeft += 1
            swapL.toggle()
        } else {
            scoreRight += 1
            swapR.toggle()
        }
        send(action: "addPoint", side: side)
    }

    func fault() {
        if gameMode == "singles" {
            serving = (serving == "left") ? "right" : "left"
            server = 1
            isFirstServer = true
        } else {
            if isFirstServer {
                server = (server == 1) ? 2 : 1
                isFirstServer = false
            } else {
                serverOneIsAltLeft = !swapL
                serverOneIsAltRight = swapR
                serving = (serving == "left") ? "right" : "left"
                server = 1
                isFirstServer = true
            }
        }
        send(action: "fault", side: "")
    }

    func resetGame() {
        scoreLeft = 0
        scoreRight = 0
        serving = "left"
        server = (gameMode == "singles") ? 1 : 2
        swapL = false
        swapR = false
        isFirstServer = false
        serverOneIsAltLeft = false
        serverOneIsAltRight = false
        send(action: "reset", side: "")
    }

    func send(action: String, side: String) {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["action": action, "side": side]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Watch send error: \(error)")
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let sL = message["sL"] as? Int, let sR = message["sR"] as? Int {
                self.scoreLeft = sL
                self.scoreRight = sR
            }
            if let pL = message["playersLeft"] as? [String] {
                self.playersLeft = pL
            }
            if let pR = message["playersRight"] as? [String] {
                self.playersRight = pR
            }
            if let s = message["serving"] as? String {
                self.serving = s
            }
            if let sv = message["server"] as? Int {
                self.server = sv
            }
            if let m = message["gameMode"] as? String {
                self.gameMode = m
            }
            if let ifs = message["isFirstServer"] as? Bool {
                self.isFirstServer = ifs
            }
            if let altL = message["serverOneIsAltLeft"] as? Bool {
                self.serverOneIsAltLeft = altL
            }
            if let altR = message["serverOneIsAltRight"] as? Bool {
                self.serverOneIsAltRight = altR
            }
            if let sw = message["swapL"] as? Bool {
                self.swapL = sw
            }
            if let sw = message["swapR"] as? Bool {
                self.swapR = sw
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
}
