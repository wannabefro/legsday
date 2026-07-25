import SpriteKit
import UIKit
import LegdaySim

/// The render/sync layer (KTD-4): `update(_:)` feeds real dt into the sim's
/// fixed-step accumulator, then mirrors the state snapshot onto pooled sprites.
/// No gameplay lives here; the sim owns all state and time.
final class RunScene: SKScene {
    private var sim: RunSim!
    private var atlas = PlaceholderAtlas()
    private var lastUpdate: TimeInterval = 0

    private let world = SKNode()      // foes, motes, hero
    private let effects = SKNode()    // transient bolts/flashes
    private var heroNode: SKSpriteNode!
    private var fog: FogNode!
    private var hud: HudNode!
    private var cardLayer: CardVisual!
    private var foePool: NodePool!
    private var motePool: NodePool!
    private var corpses: CorpseLayer!
    private let feelNode = SKNode()   // cloak + lantern, behind the hero
    private let cloakNode = SKShapeNode()
    private let lanternLine = SKShapeNode()
    private var lanternBob: SKSpriteNode!

    // Input: the first touch owns the run; others are ignored (R1/U8).
    private var owningTouch: UITouch?
    private var touchInput = TouchInputAccumulator()

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0x0F / 255.0, green: 0x0C / 255.0, blue: 0x0A / 255.0, alpha: 1)
        view.ignoresSiblingOrder = true
        scaleMode = .resizeFill
        anchorPoint = .zero

        sim = RunSim(tunables: try! Tunables.bundled(),
                     viewport: Vec2(size.width, size.height),
                     seed: 0x1E6DA9,
                     catalog: try! CardCatalog.bundled()) // a run plays from cards.json (U10)

        physicsWorld.gravity = CGVector(dx: 0, dy: -9)   // corpse tumble only

        feelNode.zPosition = 9
        world.zPosition = 10
        effects.zPosition = 12
        addChild(feelNode)
        addChild(world)
        addChild(effects)

        cloakNode.strokeColor = SKColor(red: 0.5, green: 0.42, blue: 0.32, alpha: 0.9)
        cloakNode.lineWidth = 4
        lanternLine.strokeColor = SKColor(white: 0.5, alpha: 0.6)
        lanternLine.lineWidth = 1.5
        lanternBob = SKSpriteNode(texture: atlas.spark)
        lanternBob.color = PlaceholderAtlas.rgb(0xC99A2E)
        lanternBob.colorBlendFactor = 1
        feelNode.addChild(cloakNode)
        feelNode.addChild(lanternLine)
        feelNode.addChild(lanternBob)

        heroNode = SKSpriteNode(texture: atlas.hero)
        world.addChild(heroNode)

        // Corpse debris tumbles in a dedicated layer between feel and world.
        let corpseNode = SKNode()
        corpseNode.zPosition = 11
        addChild(corpseNode)
        corpses = CorpseLayer(parent: corpseNode, texture: atlas.foe)

        foePool = NodePool(parent: world) { [atlas] in SKSpriteNode(texture: atlas.foe) }
        motePool = NodePool(parent: world) { [atlas] in SKSpriteNode(texture: atlas.mote) }

        fog = FogNode(width: size.width)
        fog.zPosition = 20
        addChild(fog)

        cardLayer = CardVisual(sceneSize: size)
        cardLayer.zPosition = 40
        addChild(cardLayer)

        hud = HudNode(sceneSize: size, safeTop: view.safeAreaInsets.top)
        hud.zPosition = 50
        addChild(hud)
    }

    /// sim y-down / origin top-left → scene y-up / origin bottom-left.
    private func pt(_ p: Vec2) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }

    override func update(_ currentTime: TimeInterval) {
        guard sim != nil else { return }
        if lastUpdate == 0 { lastUpdate = currentTime }
        let dt = currentTime - lastUpdate
        lastUpdate = currentTime

        sim.tick(dt: dt, input: touchInput.current)
        touchInput.advance()
        syncRender()
    }

    // MARK: - Touch (first touch owns the run)

    private func simPoint(_ scene: CGPoint) -> Vec2 { Vec2(scene.x, size.height - scene.y) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard owningTouch == nil, let t = touches.first else { return }
        owningTouch = t
        touchInput.down(simPoint(t.location(in: self)))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = owningTouch, touches.contains(t) else { return }
        touchInput.move(simPoint(t.location(in: self)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = owningTouch, touches.contains(t) else { return }
        touchInput.up(simPoint(t.location(in: self)))
        owningTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = owningTouch, touches.contains(t) else { return }
        touchInput.cancel(simPoint(t.location(in: self)))
        owningTouch = nil
    }

    private func syncRender() {
        let s = sim.state

        heroNode.position = pt(s.hero.pos)
        heroNode.texture = s.heroInFog ? atlas.heroSubmerged : atlas.hero
        heroNode.alpha = (s.hero.invuln > 0 && Int(s.time * 18) % 2 == 0) ? 0.3 : 1

        foePool.sync(s.foes, id: { $0.id }) { [atlas] foe, node in
            node.position = self.pt(foe.pos)
            node.texture = foe.elite ? atlas.elite : atlas.foe
            node.setScale(foe.elite ? 1 : foe.radius / 9)
        }
        motePool.sync(s.motes, id: { $0.id }) { mote, node in
            node.position = self.pt(mote.pos)
        }

        // Cloak (verlet) + lantern (pendulum), in scene space.
        let cloakPath = CGMutablePath()
        cloakPath.move(to: pt(s.cloak.points[0]))
        for p in s.cloak.points.dropFirst() { cloakPath.addLine(to: pt(p)) }
        cloakNode.path = cloakPath
        let lanternLen = 26.0
        let bobSim = Vec2(s.hero.pos.x + lanternLen * sin(s.lantern.angle),
                          s.hero.pos.y + lanternLen * cos(s.lantern.angle))
        let bob = pt(bobSim), pivot = pt(s.hero.pos)
        lanternBob.position = bob
        let ll = CGMutablePath(); ll.move(to: pivot); ll.addLine(to: bob)
        lanternLine.path = ll

        // Fog: flat line + spring displacements, in scene space.
        let topY = size.height - CGFloat(sim.fogLineY())
        fog.update(topY: topY, heights: s.fogSurface.heights)
        corpses.cull(belowY: topY)

        for event in s.frameEvents { spawn(event) }

        cardLayer.update(card: s.card, charge: s.charge, essNeed: s.essNeed, sceneSize: size)
        hud.update(essence: s.essence, fathoms: s.fathoms, felled: s.kills, fates: s.deck.count)
    }

    /// Cosmetic-only transient effects (SKAction is fine here — never gameplay).
    private func spawn(_ event: FrameEvent) {
        switch event {
        case let .attack(from, to):
            let a = pt(from), b = pt(to)
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: a); path.addLine(to: b)
            line.path = path
            line.strokeColor = SKColor(white: 0.9, alpha: 0.8)
            line.lineWidth = 2
            effects.addChild(line)
            line.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        case let .heroShoved(at):
            flash(at: pt(at), color: SKColor(white: 0.9, alpha: 0.9), radius: 20)
        case let .foeDown(at, elite):
            let p = pt(at)
            flash(at: p, color: PlaceholderAtlas.rgb(0xC99A2E), radius: elite ? 12 : 7)
            // Pop up and outward; gravity tumbles it down toward the fog splash.
            let dx = (p.x - size.width / 2) / size.width // −0.5…0.5
            corpses.spawn(at: p, elite: elite, impulse: CGVector(dx: dx * 6, dy: 4))
        case let .moteCollected(at):
            flash(at: pt(at), color: PlaceholderAtlas.rgb(0x8A6FB3), radius: 6)
        case .moteLost:
            break
        }
    }

    private func flash(at p: CGPoint, color: SKColor, radius: CGFloat) {
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = p
        node.strokeColor = color
        node.lineWidth = 3
        node.fillColor = .clear
        effects.addChild(node)
        node.run(.group([
            .scale(to: 2.4, duration: 0.18),
            .fadeOut(withDuration: 0.18),
        ]))
        node.run(.sequence([.wait(forDuration: 0.18), .removeFromParent()]))
    }
}
