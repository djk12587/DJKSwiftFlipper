//
//  FlipperReDo.swift
//  DJKSwiftFlipper
//
//  Created by Koza, Daniel on 7/13/15.
//  Copyright (c) 2015 Daniel Koza. All rights reserved.
//

import UIKit

public enum FlipperState {
    case began
    case active
    case inactive
}

@objc public protocol DJKFlipperDataSource {
    func numberOfPages(_ flipper: DJKFlipperView) -> NSInteger
    func viewForPage(_ page: NSInteger, flipper: DJKFlipperView) -> UIView
}

open class DJKFlipperView: UIView {

    //MARK: - Property Declarations

    fileprivate var flipOrientation: FlipOrientation
    var viewControllerSnapShots: [UIImage?] = []
    open var dataSource: DJKFlipperDataSource?

    lazy var staticView: DJKStaticView = {
        let view = DJKStaticView(frame: self.frame, flipOrientation: self.flipOrientation)
        return view
    }()

    var flipperState = FlipperState.inactive
    var activeView: UIView?
    var currentPage = 0
    var animatingLayers: [DJKAnimationLayer] = []
    public var isInteractionToNilPagesDisabled: Bool = true // for first and last page

    //MARK: - Initialization
    
    public init(flipOrientation: FlipOrientation) {
        self.flipOrientation = flipOrientation
        super.init(frame: .zero)
        initHelper()
    }
    
    public init(frame: CGRect, flipOrientation: FlipOrientation) {
        self.flipOrientation = flipOrientation
        super.init(frame: frame)
        initHelper()
    }

    required public init?(coder aDecoder: NSCoder) {
        flipOrientation = .horizontal
        super.init(coder: aDecoder)
        initHelper()
    }

    func initHelper() {
        NotificationCenter.default.addObserver(self, selector: #selector(DJKFlipperView.deviceOrientationDidChangeNotification), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DJKFlipperView.clearAnimations), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(DJKFlipperView.pan(_:)))
        self.addGestureRecognizer(panGesture)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        self.staticView.updateFrame(self.frame)
    }

    func updateTheActiveView() {
        if viewControllerSnapShots.count > 0 {
            currentPage = viewControllerSnapShots.count <= currentPage ? viewControllerSnapShots.count - 1 : currentPage
        }
        if let dataSource = self.dataSource {
            if dataSource.numberOfPages(self) > 0 {

                if let activeView = self.activeView {
                    if activeView.isDescendant(of: self) {
                        activeView.removeFromSuperview()
                    }
                }

                self.activeView = dataSource.viewForPage(self.currentPage, flipper: self)
                self.addSubview(self.activeView!)

                //set up the constraints
                self.activeView?.translatesAutoresizingMaskIntoConstraints = false
                let viewDictionary = ["activeView": self.activeView!]
                let constraintTop = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[activeView]-0-|", options: NSLayoutFormatOptions.alignAllTop, metrics: nil, views: viewDictionary)
                let constraintLeft = NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[activeView]-0-|", options: NSLayoutFormatOptions.alignAllLeft, metrics: nil, views: viewDictionary)

                self.addConstraints(constraintTop)
                self.addConstraints(constraintLeft)

            }
        }
    }

    //MARK: - Pan Gesture States

    func pan(_ gesture: UIPanGestureRecognizer) {
        let translation: CGFloat
        let progress: CGFloat
        if flipOrientation == .horizontal {
            translation = gesture.translation(in: gesture.view!).x
            progress = translation / gesture.view!.bounds.size.width
        } else {
            translation = gesture.translation(in: gesture.view!).y
            progress = translation / gesture.view!.bounds.size.height
        }
        
        switch (gesture.state) {
        case .began:
            panBegan(gesture)
        case .changed:
            panChanged(gesture, translation: translation, progress: progress)
        case .ended:
            panEnded(gesture, translation: translation)
        case .cancelled:
            enableGesture(gesture, enable: true)
        case .failed:
            print("Failed")
        case .possible:
            print("Possible")
        }
    }

    //MARK: Pan Gesture State Began

    func panBegan(_ gesture: UIPanGestureRecognizer) {
        if checkIfAnimationsArePassedHalfway() != true {
            enableGesture(gesture, enable: false)
        } else {

            if flipperState == .inactive {
                flipperState = .began
            }

            let animationLayer = DJKAnimationLayer(frame: self.staticView.rightOrBottomSide.bounds, isFirstOrLast: false, flipOrientation: flipOrientation)

            //if an animation has a lower zPosition then it will not be visible throughout the entire animation cycle
            if let hiZAnimLayer = getHighestZIndexDJKAnimationLayer() {
                animationLayer.zPosition = hiZAnimLayer.zPosition + animationLayer.bounds.size.height
            } else {
                animationLayer.zPosition = 0
            }

            animatingLayers.append(animationLayer)
        }
    }

    //MARK: Pan Began Helpers

    func checkIfAnimationsArePassedHalfway() -> Bool {
        var passedHalfWay = false
        if flipperState == FlipperState.inactive {
            passedHalfWay = true
        } else if animatingLayers.count > 0 {
            //LOOP through this and check the new animation layer with current animations to make sure we dont allow the same animation to happen on a flip up
            for animLayer in animatingLayers {
                let animationLayer = animLayer as DJKAnimationLayer
                var layerIsPassedHalfway = false

                let rotationX = animationLayer.presentation()?.value(forKeyPath: "transform.rotation.x") as? CGFloat ?? 0
                let rotationY = animationLayer.presentation()?.value(forKeyPath: "transform.rotation.y") as? CGFloat ?? 0
                switch animationLayer.flipDirection {
                case .right: layerIsPassedHalfway = rotationX > 0
                case .left: layerIsPassedHalfway = rotationX == 0
                case .bottom: layerIsPassedHalfway = rotationY > 0
                case .top: layerIsPassedHalfway = rotationY == 0
                case .notSet: layerIsPassedHalfway = true
                }

                if layerIsPassedHalfway == false {
                    passedHalfWay = false
                    break
                } else {
                    passedHalfWay = true
                }
            }
        } else {
            passedHalfWay = true
        }

        return passedHalfWay
    }

    //MARK:Pan Gesture State Changed

    func panChanged(_ gesture: UIPanGestureRecognizer, translation: CGFloat, progress: CGFloat) {
        let progress = progress

        if let currentDJKAnimationLayer = animatingLayers.last {
            if currentDJKAnimationLayer.flipAnimationStatus == .beginning {
                animationStatusBeginning(currentDJKAnimationLayer, translation: translation, progress: progress, gesture: gesture)
            } else if currentDJKAnimationLayer.flipAnimationStatus == .active {
                animationStatusActive(currentDJKAnimationLayer, translation: translation, progress: progress)
            } else if currentDJKAnimationLayer.flipAnimationStatus == .completing {
                enableGesture(gesture, enable: false)
                animationStatusCompleting(currentDJKAnimationLayer)
            }
        }
    }

    //MARK: Pan Gesture State Ended

    func panEnded(_ gesture: UIPanGestureRecognizer, translation: CGFloat) {
        
        if let currentDJKAnimationLayer = animatingLayers.last {
            if currentDJKAnimationLayer.flipDirection == .notSet {
                    flipperState = .active
                
                    currentDJKAnimationLayer.updateFlipDirection(getFlipDirection(translation))
                    
                    if handleConflictingAnimationsWithDJKAnimationLayer(currentDJKAnimationLayer) == false {
                        currentDJKAnimationLayer.flipAnimationStatus = .completing
                        
                        updateViewControllerSnapShotsWithCurrentPage(self.currentPage)
                        setUpDJKAnimationLayerFrontAndBack(currentDJKAnimationLayer)
                        setUpStaticLayerForTheDJKAnimationLayer(currentDJKAnimationLayer)
                        
                        self.layer.addSublayer(currentDJKAnimationLayer)
                        CATransaction.flush()
                        addDJKAnimationLayer()
                    }
                setUpForFlip(currentDJKAnimationLayer, progress: 1.0, animated: true, clearFlip: true)
                return
            }
            
            currentDJKAnimationLayer.flipAnimationStatus = .completing

            if didFlipToNewPage(currentDJKAnimationLayer, gesture: gesture, translation: translation) == true {
                setUpForFlip(currentDJKAnimationLayer, progress: 1.0, animated: true, clearFlip: true)
            } else {
                if currentDJKAnimationLayer.isFirstOrLastPage == false {
                    handleDidNotFlipToNewPage(currentDJKAnimationLayer)
                }
                setUpForFlip(currentDJKAnimationLayer, progress: 0.0, animated: true, clearFlip: true)
            }
        }
    }

    //MARK: Pan Ended Helpers

    func didFlipToNewPage(_ animationLayer: DJKAnimationLayer, gesture: UIPanGestureRecognizer, translation: CGFloat) -> Bool {

        let releaseSpeed = getReleaseSpeed(translation, gesture: gesture)

        var didFlipToNewPage = false
        
        let leftOrTop: FlipDirection = flipOrientation == .horizontal ? .left : .top
        let rightOrBottom: FlipDirection = flipOrientation == .horizontal ? .right : .bottom
        if animationLayer.flipDirection == leftOrTop && fabs(releaseSpeed) > DJKFlipperConstants.SpeedThreshold && !animationLayer.isFirstOrLastPage && releaseSpeed < 0 ||
            animationLayer.flipDirection == rightOrBottom && fabs(releaseSpeed) > DJKFlipperConstants.SpeedThreshold && !animationLayer.isFirstOrLastPage && releaseSpeed > 0 {
            didFlipToNewPage = true
        }

        return didFlipToNewPage
    }

    func getReleaseSpeed(_ translation: CGFloat, gesture: UIPanGestureRecognizer) -> CGFloat {
        let releaseSpeed: CGFloat
        if flipOrientation == .horizontal {
            releaseSpeed = (translation + gesture.velocity(in: self).x / 4) / self.bounds.size.width
        } else {
            releaseSpeed = (translation + gesture.velocity(in: self).y / 4) / self.bounds.size.height
        }
        return releaseSpeed
    }

    func handleDidNotFlipToNewPage(_ animationLayer: DJKAnimationLayer) {
        let leftOrTop: FlipDirection = flipOrientation == .horizontal ? .left : .top
        let rightOrBottom: FlipDirection = flipOrientation == .horizontal ? .right : .bottom
        if animationLayer.flipDirection == leftOrTop {
            animationLayer.flipDirection = rightOrBottom
            self.currentPage = self.currentPage - 1
        } else {
            animationLayer.flipDirection = leftOrTop
            self.currentPage = self.currentPage + 1
        }
    }

    //MARK: - DJKAnimationLayer States

    //MARK: DJKAnimationLayer State Began

    func animationStatusBeginning(_ currentDJKAnimationLayer: DJKAnimationLayer, translation: CGFloat, progress: CGFloat, gesture: UIPanGestureRecognizer) {
        if currentDJKAnimationLayer.flipAnimationStatus == .beginning {

            flipperState = .active

            //set currentDJKAnimationLayers direction
            currentDJKAnimationLayer.updateFlipDirection(getFlipDirection(translation))

            if handleConflictingAnimationsWithDJKAnimationLayer(currentDJKAnimationLayer) == false {
                //check if swipe is fast enough to be considered a complete page swipe
                if isIncrementalSwipe(gesture, animationLayer: currentDJKAnimationLayer) {
                    currentDJKAnimationLayer.flipAnimationStatus = .active
                } else {
                    currentDJKAnimationLayer.flipAnimationStatus = .completing
                }

                updateViewControllerSnapShotsWithCurrentPage(self.currentPage)
                setUpDJKAnimationLayerFrontAndBack(currentDJKAnimationLayer)
                setUpStaticLayerForTheDJKAnimationLayer(currentDJKAnimationLayer)

                self.layer.addSublayer(currentDJKAnimationLayer)
                //you need to perform a flush otherwise the animation duration is not honored.
                //more information can be found here http://stackoverflow.com/questions/8661355/implicit-animation-fade-in-is-not-working#comment10764056_8661741
                CATransaction.flush()

                //add the animation layer to the view
                addDJKAnimationLayer()

                if currentDJKAnimationLayer.flipAnimationStatus == .active {
                    animationStatusActive(currentDJKAnimationLayer, translation: translation, progress: progress)
                }
            } else {
                enableGesture(gesture, enable: false)
            }
        }
    }

    //MARK: DJKAnimationLayer State Begin Helpers

    func getFlipDirection(_ translation: CGFloat) -> FlipDirection {
        if translation > 0 {
            return flipOrientation == .horizontal ? .right : .bottom
        } else {
            return flipOrientation == .horizontal ? .left : .top
        }
    }

    func isIncrementalSwipe(_ gesture: UIPanGestureRecognizer, animationLayer: DJKAnimationLayer) -> Bool {

        var incrementalSwipe = false
        let velocity = flipOrientation == .horizontal ? fabs(gesture.velocity(in: self).x) : fabs(gesture.velocity(in: self).y)

        if velocity < 700 || animationLayer.isFirstOrLastPage == true {
            incrementalSwipe = true
        }

        return incrementalSwipe
    }

    func updateViewControllerSnapShotsWithCurrentPage(_ currentPage: Int) {
        if let numberOfPages = dataSource?.numberOfPages(self) {
            if currentPage <= numberOfPages - 1 {
                //set the current page snapshot
                viewControllerSnapShots[currentPage] = dataSource?.viewForPage(currentPage, flipper: self).takeSnapshot()

                if currentPage + 1 <= numberOfPages - 1 {
                    //set the right page snapshot, if there already is a screen shot then dont update it
                    if viewControllerSnapShots[currentPage + 1] == nil {
                        viewControllerSnapShots[currentPage + 1] = dataSource?.viewForPage(currentPage + 1, flipper: self).takeSnapshot()
                    }
                }

                if currentPage - 1 >= 0 {
                    //set the left page snapshot, if there already is a screen shot then dont update it
                    if viewControllerSnapShots[currentPage - 1] == nil {
                        viewControllerSnapShots[currentPage - 1] = dataSource?.viewForPage(currentPage - 1, flipper: self).takeSnapshot()
                    }
                }
            }
            }
        }

        func setUpDJKAnimationLayerFrontAndBack(_ animationLayer: DJKAnimationLayer) {
            let flipDirection = animationLayer.flipDirection
            if flipDirection == .left || flipDirection == .top {
                if self.currentPage + 1 > dataSource!.numberOfPages(self) - 1 {
                    //we are at the end
                    animationLayer.flipProperties.endFlipAngle = flipDirection == .left ? -1.5 : 1.5
                    animationLayer.isFirstOrLastPage = true
                    animationLayer.setTheFrontLayer(self.viewControllerSnapShots[currentPage]!)
                } else {
                    //next page flip
                    animationLayer.setTheFrontLayer(self.viewControllerSnapShots[currentPage]!)
                    currentPage = currentPage + 1
                    animationLayer.setTheBackLayer(self.viewControllerSnapShots[currentPage]!)
                }
            } else {
                if currentPage - 1 < 0 {
                    //we are at the end
                    animationLayer.flipProperties.endFlipAngle = CGFloat(flipDirection == .right ? (-.pi + 1.5) : (.pi - 1.5))
                    animationLayer.isFirstOrLastPage = true
                    animationLayer.setTheBackLayer(viewControllerSnapShots[currentPage]!)

                } else {
                    //previous page flip
                    animationLayer.setTheBackLayer(self.viewControllerSnapShots[currentPage]!)
                    currentPage = currentPage - 1
                    animationLayer.setTheFrontLayer(self.viewControllerSnapShots[currentPage]!)
                }
            }
        }

        func setUpStaticLayerForTheDJKAnimationLayer(_ animationLayer: DJKAnimationLayer) {
            let leftOrTop: DJKStaticView.ImageSide = flipOrientation == .horizontal ? .left : .top
            let rightOrBottom: DJKStaticView.ImageSide = flipOrientation == .horizontal ? .right : .bottom
            if animationLayer.flipDirection == .left || animationLayer.flipDirection == .top {
                if animationLayer.isFirstOrLastPage == true {
                    staticView.set(image: viewControllerSnapShots[currentPage]!, forSide: leftOrTop)
                } else {
                    staticView.set(image: viewControllerSnapShots[currentPage - 1]!, forSide: leftOrTop)
                    staticView.set(image: viewControllerSnapShots[currentPage]!, forSide: rightOrBottom)
                }
            } else if animationLayer.flipDirection == .right || animationLayer.flipDirection == .bottom  {
                if animationLayer.isFirstOrLastPage == true && animatingLayers.count <= 1 {
                    staticView.set(image: viewControllerSnapShots[currentPage]!, forSide: rightOrBottom)
                } else {
                    staticView.set(image: viewControllerSnapShots[currentPage + 1]!, forSide: rightOrBottom)
                    staticView.set(image: viewControllerSnapShots[currentPage]!, forSide: leftOrTop)
                }
            }
        }

        func addDJKAnimationLayer() {
            self.layer.addSublayer(staticView)
            CATransaction.flush()

            if let activeView = self.activeView {
                activeView.removeFromSuperview()
            }
        }

        //MARK: DJKAnimationLayer State Active

        func animationStatusActive(_ currentDJKAnimationLayer: DJKAnimationLayer, translation: CGFloat, progress: CGFloat) {
            performIncrementalAnimationToLayer(currentDJKAnimationLayer, translation: translation, progress: progress)
        }

        //MARK: DJKAnimationLayer State Active Helpers

        func performIncrementalAnimationToLayer(_ animationLayer: DJKAnimationLayer, translation: CGFloat, progress: CGFloat) {
            var progress = progress

            if translation > 0 {
                progress = max(progress, 0)
            } else {
                progress = min(progress, 0)
            }

            progress = fabs(progress)
            setUpForFlip(animationLayer, progress: progress, animated: false, clearFlip: false)
        }

        //MARK DJKAnimationLayer State Complete

        func animationStatusCompleting(_ animationLayer: DJKAnimationLayer) {
            performCompleteAnimationToLayer(animationLayer)
        }

        //MARK: Animation State Complete Helpers

        func performCompleteAnimationToLayer(_ animationLayer: DJKAnimationLayer) {
            setUpForFlip(animationLayer, progress: 1.0, animated: true, clearFlip: true)
        }

        //MARK: - Animation Conflict Detection

        func handleConflictingAnimationsWithDJKAnimationLayer(_ animationLayer: DJKAnimationLayer) -> Bool {

            //check if there is an animation layer before that is still animating at the opposite swipe direction
            var animationConflict = false
            if animatingLayers.count > 1 {

                if let oppositeDJKAnimationLayer = getHighestDJKAnimationLayerFromDirection(getOppositeAnimationDirectionFromLayer(animationLayer)) {
                    if oppositeDJKAnimationLayer.isFirstOrLastPage == false {

                        animationConflict = true
                        //we now need to remove the newly added layer
                        removeDJKAnimationLayer(animationLayer)
                        reverseAnimationForLayer(oppositeDJKAnimationLayer)

                    }
                }
            }
            return animationConflict
        }

        func getHighestDJKAnimationLayerFromDirection(_ flipDirection: FlipDirection) -> DJKAnimationLayer? {

            var animationsInSameDirection: [DJKAnimationLayer] = []

            for animLayer in animatingLayers {
                if animLayer.flipDirection == flipDirection {
                    animationsInSameDirection.append(animLayer)
                }
            }

            return animationsInSameDirection.sorted(by: { $0.zPosition > $1.zPosition }).first
        }

        func getOppositeAnimationDirectionFromLayer(_ animationLayer: DJKAnimationLayer) -> FlipDirection {
            switch animationLayer.flipDirection {
            case .left: return .right
            case .right: return .left
            case .top: return .bottom
            case .bottom: return .top
            case .notSet: return .left
            }
        }

        func removeDJKAnimationLayer(_ animationLayer: DJKAnimationLayer) {
            animationLayer.flipAnimationStatus = .fail

            var zPos = animationLayer.bounds.size.height

            if let highestZPosAnimLayer = getHighestZIndexDJKAnimationLayer() {
                zPos = zPos + highestZPosAnimLayer.zPosition
            } else {
                zPos = 0
            }

            animatingLayers.remove(object: animationLayer)

            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            animationLayer.zPosition = zPos
            CATransaction.commit()
        }

        func reverseAnimationForLayer(_ animationLayer: DJKAnimationLayer) {
            animationLayer.flipAnimationStatus = .interrupt
            let leftOrTop: FlipDirection = flipOrientation == .horizontal ? .left : .top
            let rightOrBottom: FlipDirection = flipOrientation == .horizontal ? .right : .bottom
            if animationLayer.flipDirection == leftOrTop {
                currentPage = currentPage - 1
                animationLayer.updateFlipDirection(rightOrBottom)
                setUpForFlip(animationLayer, progress: 1.0, animated: true, clearFlip: true)
            } else if animationLayer.flipDirection == rightOrBottom {
                currentPage = currentPage + 1
                animationLayer.updateFlipDirection(leftOrTop)
                setUpForFlip(animationLayer, progress: 1.0, animated: true, clearFlip: true)
            }
        }

        //MARK: - Flip Animation Methods

        func setUpForFlip(_ animationLayer: DJKAnimationLayer, progress: CGFloat, animated: Bool, clearFlip: Bool) {
            let newAngle: CGFloat = animationLayer.flipProperties.startAngle + progress * (animationLayer.flipProperties.endFlipAngle - animationLayer.flipProperties.startAngle)
            var duration: CGFloat
            if animated == true {
                duration = getAnimationDurationFromDJKAnimationLayer(animationLayer, newAngle: newAngle)
            } else {
                duration = 0
            }
            animationLayer.flipProperties.currentAngle = newAngle

            if animationLayer.isFirstOrLastPage == true {
                setMaxAngleIfDJKAnimationLayerIsFirstOrLast(animationLayer, newAngle: newAngle)
            }
            performFlipWithDJKAnimationLayer(animationLayer, duration: duration, clearFlip: clearFlip)
        }

        func performFlipWithDJKAnimationLayer(_ animationLayer: DJKAnimationLayer, duration: CGFloat, clearFlip: Bool) {
            var t = CATransform3DIdentity
            t.m34 = 1.0 / 850
            if flipOrientation == .horizontal {
                t = CATransform3DRotate(t, animationLayer.flipProperties.currentAngle, 0, 1, 0)
            } else {
                t = CATransform3DRotate(t, animationLayer.flipProperties.currentAngle, 1, 0, 0)
            }

            CATransaction.begin()
            CATransaction.setAnimationDuration(CFTimeInterval(duration))

            //if the flip animationLayer should be cleared after its animation is completed
            if clearFlip {
                clearFlipAfterCompletion(animationLayer)
            }

            animationLayer.transform = t
            CATransaction.commit()
        }

        func clearFlipAfterCompletion(_ animationLayer: DJKAnimationLayer) {
            CATransaction.setCompletionBlock { [weak self] () -> Void in
                DispatchQueue.main.async(execute: {
                    if animationLayer.flipAnimationStatus == .interrupt {
                        animationLayer.flipAnimationStatus = .completing

                    } else if animationLayer.flipAnimationStatus == .completing {
                        animationLayer.flipAnimationStatus = .none

                        if animationLayer.isFirstOrLastPage == false {
                            CATransaction.begin()
                            CATransaction.setAnimationDuration(0)
                            if animationLayer.flipDirection == .left || animationLayer.flipDirection == .top {
                                self?.staticView.leftOrTopSide.contents = animationLayer.backLayer.contents
                            } else {
                                self?.staticView.rightOrBottomSide.contents = animationLayer.frontLayer.contents
                            }
                            CATransaction.commit()
                        }

                        self?.animatingLayers.remove(object: animationLayer)
                        animationLayer.removeFromSuperlayer()

                        if self?.animatingLayers.count == 0 {

                            self?.flipperState = .inactive
                            self?.updateTheActiveView()
                            self?.staticView.removeFromSuperlayer()
                            CATransaction.flush()
                            self?.staticView.leftOrTopSide.contents = nil
                            self?.staticView.rightOrBottomSide.contents = nil
                        } else {
                            CATransaction.flush()
                        }
                    }
                })

            }
        }

        //MARK: Flip Animation Helper Methods

        func getAnimationDurationFromDJKAnimationLayer(_ animationLayer: DJKAnimationLayer, newAngle: CGFloat) -> CGFloat {
            var durationConstant = DJKFlipperConstants.DurationConstant

            if animationLayer.isFirstOrLastPage == true {
                durationConstant = 0.5
            }
            return durationConstant * fabs((newAngle - animationLayer.flipProperties.currentAngle) / (animationLayer.flipProperties.endFlipAngle - animationLayer.flipProperties.startAngle))
        }

        func setMaxAngleIfDJKAnimationLayerIsFirstOrLast(_ animationLayer: DJKAnimationLayer, newAngle: CGFloat) {
            switch animationLayer.flipDirection {
            case .right:
                if newAngle < (isInteractionToNilPagesDisabled ? 0 : -1.4) {
                    animationLayer.flipProperties.currentAngle = isInteractionToNilPagesDisabled ? 0 : -1.4
                }
            case .left:
                if newAngle > (isInteractionToNilPagesDisabled ? -.pi : -1.8) {
                    animationLayer.flipProperties.currentAngle = isInteractionToNilPagesDisabled ? -.pi : -1.8
                }
            case .bottom:
                if newAngle > (isInteractionToNilPagesDisabled ? 0 : 1.0) {
                    animationLayer.flipProperties.currentAngle = isInteractionToNilPagesDisabled ? 0 : 1.0
                }
            case .top:
                if newAngle < (isInteractionToNilPagesDisabled ? .pi : 2.0) {
                    animationLayer.flipProperties.currentAngle = isInteractionToNilPagesDisabled ? .pi : 2.0
                }
            case .notSet: break
            }
        }

        //MARK: - Helper Methods

        func enableGesture(_ gesture: UIPanGestureRecognizer, enable: Bool) {
            gesture.isEnabled = enable
        }

        func getHighestZIndexDJKAnimationLayer() -> DJKAnimationLayer? {
            return animatingLayers.sorted(by: { $0.zPosition > $1.zPosition }).first
        }

        func clearAnimations() {
            if flipperState != .inactive {
                //remove all animation layers and update the static view
                updateTheActiveView()

                for animation in animatingLayers {
                    animation.flipAnimationStatus = .fail
                    animation.removeFromSuperlayer()
                }
                animatingLayers.removeAll(keepingCapacity: false)

                self.staticView.removeFromSuperlayer()
                CATransaction.flush()
                self.staticView.leftOrTopSide.contents = nil
                self.staticView.rightOrBottomSide.contents = nil

                flipperState = .inactive
            }
        }

        func deviceOrientationDidChangeNotification() {
            clearAnimations()
        }

        //MARK: - Public Methods

        open func reload() {
            updateTheActiveView()

            viewControllerSnapShots.removeAll(keepingCapacity: false)
            guard let dataSource = dataSource else { return }

            //set an array with capacity for total amount of possible pages
            for _ in 0..<dataSource.numberOfPages(self)
            {
                viewControllerSnapShots.append(nil)
            }
        }
    }

