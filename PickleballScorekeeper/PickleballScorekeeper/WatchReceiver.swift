import Foundation
import WatchConnectivity

protocol WatchReceiverDelegate: AnyObject {
    func watchReceiver(_ receiver: WatchReceiver, didReceiveAction action: String, side: String)
}

class WatchReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchReceiver()

    weak var delegate: WatchReceiverDelegate?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendScoreToWatch(sL: Int, sR: Int, playersLeft: [String] = [], playersRight: [String] = [], serving: String = "left", server: Int = 2, gameMode: String = "doubles", isFirstServer: Bool = false, serverOneIsAltLeft: Bool = false, serverOneIsAltRight: Bool = false) {
        guard WCSession.default.isReachable else { return }
        var message: [String: Any] = [
            "sL": sL, "sR": sR,
            "serving": serving, "server": server, "gameMode": gameMode,
            "isFirstServer": isFirstServer,
            "serverOneIsAltLeft": serverOneIsAltLeft,
            "serverOneIsAltRight": serverOneIsAltRight
        ]
        if !playersLeft.isEmpty { message["playersLeft"] = playersLeft }
        if !playersRight.isEmpty { message["playersRight"] = playersRight }
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String,
              let side = message["side"] as? String else { return }
        DispatchQueue.main.async {
            self.delegate?.watchReceiver(self, didReceiveAction: action, side: side)
        }
    }
}
