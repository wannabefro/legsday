import SpriteKit
import LegdaySim

/// The fog body with its rippling top edge. U7 rebuilds an `SKShapeNode` path
/// from the sim's spring line each frame (KTD-4 execution note: profile, and
/// escalate to an `SKWarpGeometryGrid`-deformed sprite if the frame budget
/// fails). At 48 nodes the path rebuild is cheap.
final class FogNode: SKNode {
    private let shape = SKShapeNode()
    private let width: CGFloat

    init(width: CGFloat) {
        self.width = width
        super.init()
        shape.fillColor = SKColor(red: 0.106, green: 0.078, blue: 0.153, alpha: 0.9) // #1B1427
        shape.strokeColor = SKColor(red: 0.2, green: 0.16, blue: 0.28, alpha: 0.9)
        shape.lineWidth = 1.5
        addChild(shape)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// `topY` is the flat fog line in scene space (y-up); `heights` are the
    /// spring displacements added to it.
    func update(topY: CGFloat, heights: [Double]) {
        let n = heights.count
        guard n >= 2 else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        for i in 0..<n {
            let x = CGFloat(i) / CGFloat(n - 1) * width
            let y = topY + CGFloat(heights[i]) // displacement rides the flat line
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        shape.path = path
    }
}
