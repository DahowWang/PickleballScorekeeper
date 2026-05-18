import UIKit
import WebKit

class WebViewController: UIViewController, WKScriptMessageHandler, SyncServiceDelegate, WatchReceiverDelegate {
    private var webView: WKWebView!
    private var isSyncingFromRemote = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        config.userContentController.add(self, name: "nativebridge")

        // Inject JS bridge script to intercept game actions
        let bridgeScript = WKUserScript(source: Self.bridgeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(bridgeScript)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        view.addSubview(webView)

        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            let resourceDir = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceDir)
        }

        SyncService.shared.delegate = self
        WatchReceiver.shared.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: - JS -> Swift messages
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: String],
              let action = body["action"] else { return }

        switch action {
        case "syncState":
            // JS sends full state after any action, broadcast to peers & Watch
            if !isSyncingFromRemote, let stateStr = body["state"],
               let stateData = stateStr.data(using: .utf8),
               let stateDict = try? JSONSerialization.jsonObject(with: stateData) as? [String: Any] {
                SyncService.shared.sendAction("syncState", data: stateStr)
                let sL = stateDict["sL"] as? Int ?? 0
                let sR = stateDict["sR"] as? Int ?? 0
                let pL = stateDict["playersLeft"] as? [String] ?? []
                let pR = stateDict["playersRight"] as? [String] ?? []
                let serving = stateDict["serving"] as? String ?? "left"
                let server = stateDict["server"] as? Int ?? 2
                let gameMode = stateDict["gameMode"] as? String ?? "doubles"
                let isFirstServer = stateDict["isFirstServer"] as? Bool ?? false
                let serverOneIsAltLeft = stateDict["serverOneIsAltLeft"] as? Bool ?? false
                let serverOneIsAltRight = stateDict["serverOneIsAltRight"] as? Bool ?? false
                let swapL = stateDict["swapL"] as? Bool ?? false
                let swapR = stateDict["swapR"] as? Bool ?? false
                WatchReceiver.shared.sendScoreToWatch(sL: sL, sR: sR, playersLeft: pL, playersRight: pR, serving: serving, server: server, gameMode: gameMode, isFirstServer: isFirstServer, serverOneIsAltLeft: serverOneIsAltLeft, serverOneIsAltRight: serverOneIsAltRight, swapL: swapL, swapR: swapR)
            }
        case "toggleSync":
            if SyncService.shared.isActive {
                SyncService.shared.stop()
            } else {
                SyncService.shared.start()
            }
        default:
            break
        }
    }

    // MARK: - SyncServiceDelegate
    func syncService(_ service: SyncService, didReceiveAction action: String, data: String) {
        if action == "syncState" {
            isSyncingFromRemote = true
            let escapedData = data.replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("receiveRemoteState('\(escapedData)')") { _, _ in
                self.isSyncingFromRemote = false
            }
        }
    }

    func syncService(_ service: SyncService, connectedDevicesChanged devices: [String]) {
        let count = devices.count
        let jsDevices = devices.joined(separator: ",")
        webView.evaluateJavaScript("updateSyncStatus(\(count), '\(jsDevices)')") { _, _ in }
    }

    // MARK: - WatchReceiverDelegate
    func watchReceiver(_ receiver: WatchReceiver, didReceiveAction action: String, side: String) {
        switch action {
        case "addPoint":
            webView.evaluateJavaScript("addPoint('\(side)')") { _, _ in }
        case "fault":
            webView.evaluateJavaScript("fault()") { _, _ in }
        case "undo":
            webView.evaluateJavaScript("undo()") { _, _ in }
        case "reset":
            webView.evaluateJavaScript("resetScore()") { _, _ in }
        default:
            break
        }
    }

    // MARK: - Bridge JS
    static let bridgeJS = """
    // Override game functions to broadcast state after each action
    (function() {
        const origAddPoint = window.addPoint;
        const origFault = window.fault;
        const origUndo = window.undo;
        const origResetScore = window.resetScore;

        function broadcastState() {
            const pL = [players[0].name, players[1].name];
            const pR = [players[2].name, players[3].name];
            const stateJSON = JSON.stringify({
                sL: state.sL, sR: state.sR,
                serving: state.serving, server: state.server,
                over: state.over, swapL: state.swapL, swapR: state.swapR, isFirstServer: state.isFirstServer,
                serverOneIsAltLeft: state.serverOneIsAltLeft, serverOneIsAltRight: state.serverOneIsAltRight,
                playersLeft: pL, playersRight: pR,
                gameMode: gameMode
            });
            window.webkit.messageHandlers.nativebridge.postMessage({
                action: 'syncState', state: stateJSON
            });
        }

        window.addPoint = function(s) { origAddPoint(s); broadcastState(); };
        window.fault = function() { origFault(); broadcastState(); };
        window.undo = function() { origUndo(); broadcastState(); };
        window.resetScore = function() { origResetScore(); broadcastState(); };

        // Receive state from remote device
        window.receiveRemoteState = function(jsonStr) {
            try {
                const remote = JSON.parse(jsonStr);
                state.sL = remote.sL;
                state.sR = remote.sR;
                state.serving = remote.serving;
                state.server = remote.server;
                state.over = remote.over;
                state.swapL = remote.swapL;
                state.swapR = remote.swapR;
                state.isFirstServer = remote.isFirstServer;
                state.serverOneIsAltLeft = remote.serverOneIsAltLeft || false;
                state.serverOneIsAltRight = remote.serverOneIsAltRight || false;
                render();
            } catch(e) {}
        };

        // Update sync status indicator
        window.updateSyncStatus = function(count, devices) {
            // Could show a small indicator on screen
            console.log('Connected devices: ' + count + ' - ' + devices);
        };
    })();
    """
}
