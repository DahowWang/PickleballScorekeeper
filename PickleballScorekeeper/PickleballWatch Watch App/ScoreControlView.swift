import SwiftUI

struct ScoreControlView: View {
    @StateObject private var connector = WatchConnector.shared
    @AppStorage("watchFlipped") private var flipped = false
    @State private var showResetConfirm = false

    let blueColor = Color(red: 4/255, green: 189/255, blue: 220/255)
    let redColor = Color(red: 253/255, green: 80/255, blue: 72/255)

    private func isServing(side: String, playerIndex: Int) -> Bool {
        guard connector.serving == side else { return false }
        return connector.servingPlayerIndex(side: side) == playerIndex
    }

    private var topSide: String { flipped ? "left" : "right" }
    private var bottomSide: String { flipped ? "right" : "left" }
    private var topColor: Color { flipped ? blueColor : redColor }
    private var bottomColor: Color { flipped ? redColor : blueColor }
    private var topScore: Int { flipped ? connector.scoreLeft : connector.scoreRight }
    private var bottomScore: Int { flipped ? connector.scoreRight : connector.scoreLeft }
    private var topPlayers: [String] { connector.displayPlayers(side: topSide) }
    private var bottomPlayers: [String] { connector.displayPlayers(side: bottomSide) }

    @ViewBuilder
    private func playerRow(players: [String], side: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.yellow)
                .frame(width: 7, height: 7)
                .opacity(isServing(side: side, playerIndex: 0) ? 1 : 0)

            Text(players.count > 0 ? players[0] : "")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Text(players.count > 1 ? players[1] : "")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.leading, 4)

            Circle()
                .fill(.yellow)
                .frame(width: 7, height: 7)
                .opacity(isServing(side: side, playerIndex: 1) ? 1 : 0)
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Top half
                Button(action: { connector.addPoint(side: topSide) }) {
                    ZStack {
                        topColor
                        VStack(spacing: 2) {
                            playerRow(players: topPlayers, side: topSide)
                            Text("\(topScore)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(height: geo.size.height / 2)

                // Bottom half
                Button(action: { connector.addPoint(side: bottomSide) }) {
                    ZStack {
                        bottomColor
                        VStack(spacing: 2) {
                            Text("\(bottomScore)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                            playerRow(players: bottomPlayers, side: bottomSide)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(height: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .overlay(
            Button(action: { showResetConfirm = true }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .buttonStyle(.plain)
            , alignment: .leading
        )
        .overlay(
            Button(action: { flipped.toggle() }) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .buttonStyle(.plain)
            , alignment: .trailing
        )
        .alert("新局", isPresented: $showResetConfirm) {
            Button("確定", role: .destructive) { connector.resetGame() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("重新開始？")
        }
    }
}
