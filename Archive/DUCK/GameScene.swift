import SpriteKit
import AVFoundation



class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var lastTouchLocation: CGPoint? // تخزين موقع اللمس الأخير
    var audioPlayer: AVAudioPlayer?
    var duck1: SKSpriteNode!
    var duck2: SKSpriteNode!
    var startButton: SKSpriteNode!
    var restartButton: SKSpriteNode!
    var muteButton: SKSpriteNode!
    
    var heartsDuck1: [SKSpriteNode] = []
    var heartsDuck2: [SKSpriteNode] = []
    
    var currentTurn = 1 // 1 for duck1, 2 for duck2
    var isHolding = false
    var launchPower: CGFloat = 0.0
    var maxPower: CGFloat = 800.0
    var backgroundMusic: SKAudioNode!
    var isMuted = false
    var touchStartTime: TimeInterval?
    var trajectoryLine: SKShapeNode!
    var powerBar: SKSpriteNode!
    
    struct PhysicsCategory {
        static let playerDuck: UInt32 = 1
        static let enemyDuck: UInt32 = 2
        static let bubble: UInt32 = 4
        static let wall: UInt32 = 8 // إضافة فئة الجدار
    }
    
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self

        duck1 = childNode(withName: "duck1") as? SKSpriteNode
        duck2 = childNode(withName: "duck2") as? SKSpriteNode
        startButton = childNode(withName: "startButton") as? SKSpriteNode
        restartButton = childNode(withName: "restartButton") as? SKSpriteNode
        muteButton = childNode(withName: "muteButton") as? SKSpriteNode
        
        heartsDuck1 = [
            childNode(withName: "duck1Heart1") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck1Heart2") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck1Heart3") as? SKSpriteNode ?? SKSpriteNode()
        ]
        
        heartsDuck2 = [
            childNode(withName: "duck2Heart1") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck2Heart2") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck2Heart3") as? SKSpriteNode ?? SKSpriteNode()
        ]
        
        if let musicURL = Bundle.main.url(forResource: "game_music", withExtension: "mp3") {
            backgroundMusic = SKAudioNode(url: musicURL)
            backgroundMusic.autoplayLooped = true
            addChild(backgroundMusic)
        }
        setupPhysics()  // إعداد الفيزياء
        setupDucksPhysics()  // إعداد الفيزياء للبطات
    }
    
    func setupPhysics() {  // إعداد حدود المشهد
        physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        physicsBody?.categoryBitMask = 0
        physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        physicsBody?.categoryBitMask = 0
        // إضافة جدار إلى المشهد
        let wall = SKNode()
        wall.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        wall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        wall.physicsBody?.isDynamic = false  // جدار ثابت لا يتحرك
        addChild(wall)
    }
    
    func setupDucksPhysics() {
        // تعيين الجسم الفيزيائي للبط الأول
        duck1.physicsBody = SKPhysicsBody(rectangleOf: duck1.size)
        duck1.physicsBody?.categoryBitMask = PhysicsCategory.playerDuck
        duck1.physicsBody?.collisionBitMask = PhysicsCategory.bubble
        duck1.physicsBody?.contactTestBitMask = PhysicsCategory.bubble
        duck1.physicsBody?.isDynamic = true // تم تعيينه إلى true ليكون فعالاً في التصادمات

        // تعيين الجسم الفيزيائي للبط الثاني
        duck2.physicsBody = SKPhysicsBody(rectangleOf: duck2.size)
        duck2.physicsBody?.categoryBitMask = PhysicsCategory.enemyDuck
        duck2.physicsBody?.collisionBitMask = PhysicsCategory.bubble
        duck2.physicsBody?.contactTestBitMask = PhysicsCategory.bubble
        duck2.physicsBody?.isDynamic = true // تم تعيينه إلى true ليكون فعالاً في التصادمات
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            lastTouchLocation = touch.location(in: self)
            let location = lastTouchLocation!
            
            if startButton.contains(location) {
                startButton.isHidden = true
                run(SKAction.playSoundFileNamed("button_click.mp3", waitForCompletion: false))
                return
            }
            if restartButton.contains(location) {
                restartGame()
                run(SKAction.playSoundFileNamed("button_click.mp3", waitForCompletion: false))
                return
            }
            if muteButton.contains(location) {
                toggleMute()
                run(SKAction.playSoundFileNamed("button_click.mp3", waitForCompletion: false))
                return
            }
            if (currentTurn == 1 && duck1.contains(location)) || (currentTurn == 2 && duck2.contains(location)) {
                isHolding = true
                touchStartTime = CACurrentMediaTime()
                drawTrajectory(from: location)
              
                run(SKAction.playSoundFileNamed("hold.mp3", waitForCompletion: false))
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isHolding, let touch = touches.first {
            lastTouchLocation = touch.location(in: self)
            drawTrajectory(from: lastTouchLocation!)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isHolding {
            launchPower = maxPower * 0.4  // تعيين قوة ثابتة بدلاً من حسابها من مدة الضغط
            shootBubble()
            trajectoryLine.removeFromParent()
         
            isHolding = false
            switchTurn()
        }
    }
    
    func drawTrajectory(from touchLocation: CGPoint) {
        let startPosition = currentTurn == 1 ? duck1.position : duck2.position

        let deltaX = touchLocation.x - startPosition.x
        let deltaY = touchLocation.y - startPosition.y
        let angle = atan2(deltaY, deltaX)

        let adjustedPower = launchPower * 0.8
        let gravity: CGFloat = -9.8
        let stepCount = 50  // عدد النقاط في المسار

        let path = UIBezierPath()
        path.move(to: startPosition)

        for i in 0...stepCount {
            let time = CGFloat(i) / CGFloat(stepCount)
            let x = startPosition.x + adjustedPower * cos(angle) * time
            let y = startPosition.y + adjustedPower * sin(angle) * time + 0.5 * gravity * pow(time, 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        trajectoryLine?.removeFromParent()
        trajectoryLine = SKShapeNode(path: path.cgPath)
        trajectoryLine?.strokeColor = .red
        trajectoryLine?.lineWidth = 2
        addChild(trajectoryLine!)
    }

    func shootBubble() {
        guard let lastTouchLocation = lastTouchLocation else { return }
        let startPosition = currentTurn == 1 ? duck1.position : duck2.position

        // تحديد المسافة بين البطّة والبابل عند الإطلاق
        let offset: CGFloat = 40 // يمكن زيادة أو تقليل هذه القيمة لتحريك البابل أكثر
        let bubbleStartPosition = CGPoint(x: startPosition.x, y: startPosition.y + duck1.size.height / 2 + offset)

        let bubble = SKSpriteNode(imageNamed: "bubble")
        bubble.size = CGSize(width: 50, height: 50)
        bubble.position = bubbleStartPosition

        // تعيين الجسم الفيزيائي للبابل قبل إضافته إلى المشهد
        bubble.physicsBody = SKPhysicsBody(circleOfRadius: bubble.size.width / 2)
        bubble.physicsBody?.categoryBitMask = PhysicsCategory.bubble

        // تأكد أن البابل لا يصطدم بالبطّة التي أطلقته
        if currentTurn == 1 {
            bubble.physicsBody?.collisionBitMask = PhysicsCategory.enemyDuck // يتصادم مع البطّة المعادية فقط
        } else {
            bubble.physicsBody?.collisionBitMask = PhysicsCategory.playerDuck // يتصادم مع البطّة المعادية فقط
        }
        
        bubble.physicsBody?.contactTestBitMask = PhysicsCategory.playerDuck | PhysicsCategory.enemyDuck | PhysicsCategory.wall // يحدث التفاعل عند الاصطدام بأي بطّة أو جدار
        bubble.physicsBody?.isDynamic = true
        bubble.physicsBody?.affectedByGravity = true
        bubble.physicsBody?.linearDamping = 0.3
        bubble.physicsBody?.angularDamping = 0.5
        bubble.physicsBody?.restitution = 0.2
        addChild(bubble)

        let deltaX = lastTouchLocation.x - bubble.position.x
        let deltaY = lastTouchLocation.y - bubble.position.y
        let angle = atan2(deltaY, deltaX)

        let launchPowerAdjusted = launchPower * 0.4 // تعديل القوة لجعلها أكثر واقعية
        let velocityX = launchPowerAdjusted * cos(angle)
        let velocityY = launchPowerAdjusted * sin(angle)

        bubble.physicsBody?.applyImpulse(CGVector(dx: velocityX, dy: velocityY))  // تطبيق القوة بشكل منحني
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        
        if bodyA.categoryBitMask == PhysicsCategory.bubble && bodyB.categoryBitMask == PhysicsCategory.enemyDuck {
            handleBubbleHitDuck(bubble: bodyA.node as? SKSpriteNode, duck: bodyB.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
            playBubblePopAndCollisionSound()
        } else if bodyB.categoryBitMask == PhysicsCategory.bubble && bodyA.categoryBitMask == PhysicsCategory.enemyDuck {
            handleBubbleHitDuck(bubble: bodyB.node as? SKSpriteNode, duck: bodyA.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
            playBubblePopAndCollisionSound()
        } else if bodyA.categoryBitMask == PhysicsCategory.bubble && bodyB.categoryBitMask == PhysicsCategory.playerDuck {
            handleBubbleHitDuck(bubble: bodyA.node as? SKSpriteNode, duck: bodyB.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
            playBubblePopAndCollisionSound()
        } else if bodyB.categoryBitMask == PhysicsCategory.bubble && bodyA.categoryBitMask == PhysicsCategory.playerDuck {
            handleBubbleHitDuck(bubble: bodyB.node as? SKSpriteNode, duck: bodyA.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
            playBubblePopAndCollisionSound()
        } else if bodyA.categoryBitMask == PhysicsCategory.bubble && bodyB.categoryBitMask == PhysicsCategory.wall {
            handleBubbleHitWall(bubble: bodyA.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالجدار
            playBubblePopAndCollisionSound()
        } else if bodyB.categoryBitMask == PhysicsCategory.bubble && bodyA.categoryBitMask == PhysicsCategory.wall {
            handleBubbleHitWall(bubble: bodyB.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالجدار
            playBubblePopAndCollisionSound()
        }
    }

    func playBubblePopAndCollisionSound() {
        // الصوت الأول: bubble_pop.mp3
        let soundAction1 = SKAction.playSoundFileNamed("bubble_pop.mp3", waitForCompletion: false)
        
        // الصوت الثاني: collision_sound_2.mp3
        let soundAction2 = SKAction.playSoundFileNamed("collision_sound_2.mp3", waitForCompletion: false)
        
        
        // إضافة الصوتين كإجراءات متتالية مع التأخير
        let groupAction = SKAction.group([soundAction1, soundAction2])
        run(groupAction)
    }

    func handleBubbleHitDuck(bubble: SKSpriteNode?, duck: SKSpriteNode?) {
        guard let bubble = bubble, let duck = duck else { return }

        bubble.removeFromParent()
        run(SKAction.playSoundFileNamed("bubble_pop.mp3", waitForCompletion: false))

        let flashRed = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.2),
            SKAction.wait(forDuration: 0.1),
            SKAction.colorize(with: .clear, colorBlendFactor: 0.0, duration: 0.2)
        ])
        duck.run(SKAction.repeat(flashRed, count: 3))

        if duck == duck1 {
            removeHeart(from: &heartsDuck1)
        } else {
            removeHeart(from: &heartsDuck2)
        }
    }

    func handleBubbleHitWall(bubble: SKSpriteNode?) {
        bubble?.removeFromParent()
        run(SKAction.playSoundFileNamed("bubble_pop.mp3", waitForCompletion: false)) // نفس الصوت عند الاصطدام بالجدار
    }

    func switchTurn() {
        currentTurn = (currentTurn == 1) ? 2 : 1
        
        // إيقاف الأنيميشن عن البطّة الحالية
        if currentTurn == 1 {
            // تأكد من إيقاف الأنيميشن عن البطّة الثانية
            duck2.removeAllActions()
            startDuckAnimation(duck: duck1) // تشغيل الأنيميشن للبطة 1
        } else {
            // تأكد من إيقاف الأنيميشن عن البطّة الأولى
            duck1.removeAllActions()
            startDuckAnimation(duck: duck2) // تشغيل الأنيميشن للبطة 2
        }
    }

    
    func restartGame() {
        if let scene = SKScene(fileNamed: "GameScene") {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.5))
        }
    }

    func endGame() {
        let gameOverLabel = SKLabelNode(fontNamed: "Chalkduster")
        gameOverLabel.text = "Game Over!"
        gameOverLabel.fontSize = 50
        gameOverLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(gameOverLabel)

        restartButton.isHidden = false
        restartButton.zPosition = 1  // تأكد من أنه في المقدمة

        // هنا نضيف صوت الفوز عندما ينتهي اللاعب بنجاح
        playVictorySound()
    }

    func playVictorySound() {
        // تشغيل الصوت عند الفوز (يمكنك تعديل مسار الصوت هنا)
        run(SKAction.playSoundFileNamed("win_sound.mp3", waitForCompletion: false))
    }
    func removeHeart(from hearts: inout [SKSpriteNode]) {
        if let lastHeart = hearts.popLast() {
            print("Heart removed")
            lastHeart.removeFromParent()
        }
        if hearts.isEmpty {
            print("Game Over")
            endGame()
        }
    }
    func startDuckAnimation(duck: SKSpriteNode) {
        // إيقاف الأنيميشن الحالي للبطة (إذا كان موجودًا)
        duck.removeAllActions()

        // تحقق من دور البطّة الحالي
        if (duck == duck1 && currentTurn == 1) || (duck == duck2 && currentTurn == 2) {
            // إنشاء الأنيميشن باستخدام الصور
            var animationTextures: [SKTexture]
            
            if duck == duck1 {
                animationTextures = [
                    SKTexture(imageNamed: "ducky_3_1_inverse"),
                    SKTexture(imageNamed: "ducky_3_2_inverse"),
                    SKTexture(imageNamed: "ducky_3_3_inverse")
                ]
            } else {
                animationTextures = [
                    SKTexture(imageNamed: "ducky_2_1_inverse"),
                    SKTexture(imageNamed: "ducky_2_2_inverse"),
                    SKTexture(imageNamed: "ducky_2_3_inverse")
                ]
            }

            // إنشاء حركة الأنيميشن
            let animationAction = SKAction.animate(with: animationTextures, timePerFrame: 0.2) // 0.2 ثانية لكل صورة
            let repeatAction = SKAction.repeatForever(animationAction) // تكرار الأنيميشن باستمرار

            // تشغيل الأنيميشن
            duck.run(repeatAction)
        } else {
            // إذا لم يكن الدور للبطة المعينة، تأكد من أن الأنيميشن لا يعمل
            duck.removeAllActions() // إيقاف الأنيميشن إذا كان موجودًا
        }
    }


    func toggleMute() {
        if isMuted {
            backgroundMusic.run(SKAction.stop())
            isMuted = false
        } else {
            backgroundMusic.run(SKAction.play())
            isMuted = true
        }
    }
    func playShortenedSoundWithAVPlayer() {
        if let path = Bundle.main.path(forResource: "collision_sound_2.mp3", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                
                // تحديد فترة تشغيل الصوت (مثلاً، 1 ثانية)
                audioPlayer?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // توقيف الصوت بعد 1 ثانية
                    self.audioPlayer?.stop()
                }
            } catch {
                print("Error loading audio file")
            }
        }
    }
}
