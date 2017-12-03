//
//  AnimationLayer.swift
//  PageFlipper
//
//  Created by Daniel Koza on 10/2/14.
//  Copyright (c) 2014 Daniel Koza. All rights reserved.
//

import UIKit
import Darwin

struct AnimationProperties {
    var currentAngle: CGFloat
    var startAngle: CGFloat
    var endFlipAngle: CGFloat
}

public enum FlipOrientation {
    case horizontal
    case vertical
}

enum FlipDirection {
    case left
    case right
    case top
    case bottom
    case notSet
}

enum FlipAnimationStatus {
    case none
    case beginning
    case active
    case completing
    case complete
    case interrupt
    case fail
}

class DJKAnimationLayer: CATransformLayer {

    fileprivate var flipOrientation: FlipOrientation
    var flipDirection: FlipDirection = .notSet
    var flipAnimationStatus = FlipAnimationStatus.none
    var flipProperties = AnimationProperties(currentAngle: 0, startAngle: 0, endFlipAngle: .pi)
    var isFirstOrLastPage: Bool = false

    lazy var frontLayer: CALayer = {
        var fLayer = CALayer(layer: self)
        fLayer.frame = self.bounds
        fLayer.isDoubleSided = false
        if self.flipOrientation == .horizontal {
            fLayer.transform = CATransform3DMakeRotation(.pi, 0, 1.0, 0)
        } else {
            fLayer.transform = CATransform3DMakeRotation(-.pi, 1.0, 0, 0)
        }
        fLayer.backgroundColor = UIColor.black.cgColor

        self.addSublayer(fLayer)
        return fLayer
    }()

    lazy var backLayer: CALayer = {
        var bLayer = CALayer(layer: self)
        bLayer.frame = self.bounds
        bLayer.isDoubleSided = false
        if self.flipOrientation == .horizontal {
            bLayer.transform = CATransform3DMakeRotation(0, 0, 1.0, 0)
        } else {
            bLayer.transform = CATransform3DMakeRotation(0, 1, 0, 0)
        }
        bLayer.backgroundColor = UIColor.green.cgColor

        self.addSublayer(bLayer)
        return bLayer
    }()

     init(frame: CGRect, isFirstOrLast: Bool, flipOrientation: FlipOrientation) {
        self.flipOrientation = flipOrientation
        super.init()
        flipAnimationStatus = .beginning
        anchorPoint = flipOrientation == .horizontal ? CGPoint(x: 1.0, y: 0.5) : CGPoint(x: 0.5, y: 1.0)
        self.frame = frame

        isFirstOrLastPage = isFirstOrLast
    }
    
    override init(layer: Any) {
        flipOrientation = .vertical
        super.init(layer: layer)
        flipAnimationStatus = .beginning
        anchorPoint = flipOrientation == .horizontal ? CGPoint(x: 1.0, y: 0.5) : CGPoint(x: 0.5, y: 1.0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateFlipDirection(_ direction: FlipDirection) {
        flipDirection = direction
        switch flipDirection {
        case .left:
            flipProperties.currentAngle = -.pi
            flipProperties.startAngle = -.pi
            flipProperties.endFlipAngle = 0 - 0.000001 // fixes rotation direction on swipe
            transform = CATransform3DMakeRotation(.pi, 0, 1, 0)
        case .right:
            flipProperties.currentAngle = 0
            flipProperties.startAngle = 0
            flipProperties.endFlipAngle = -.pi
            transform = CATransform3DMakeRotation(0, 0, 1, 0)
        case .top:
            flipProperties.currentAngle = .pi
            flipProperties.startAngle = .pi
            flipProperties.endFlipAngle = 0 + 0.000001 // fixes rotation direction on swipe
            transform = CATransform3DMakeRotation(-.pi, 1, 0, 0)
        case .bottom:
            flipProperties.currentAngle = 0
            flipProperties.startAngle = 0 + 0.000001
            flipProperties.endFlipAngle = .pi - 0.000001 // fixes rotation direction on swipe
            transform = CATransform3DMakeRotation(0, 1, 0, 0)
        case .notSet: break
        }
    }

    func setTheFrontLayer(_ image: UIImage) {
        let frontImgRef: CGImage?
        if flipOrientation == .horizontal {
            frontImgRef = image.cgImage?.cropping(to: CGRect(x: image.size.width / 2 * UIScreen.main.scale, y: 0, width: image.size.width / 2 * UIScreen.main.scale, height: image.size.height * UIScreen.main.scale))
        } else {
            frontImgRef = image.cgImage?.cropping(to: CGRect(x: 0, y: image.size.height / 2 * UIScreen.main.scale, width: image.size.width * UIScreen.main.scale, height: image.size.height / 2 * UIScreen.main.scale))

        }
        frontLayer.contents = frontImgRef
    }

    func setTheBackLayer(_ image: UIImage) {
        let backImageRef: CGImage?
        if flipOrientation == .horizontal {
            backImageRef = image.cgImage?.cropping(to: CGRect(x: 0, y: 0, width: image.size.width / 2 * UIScreen.main.scale, height: image.size.height * UIScreen.main.scale))
        } else {
            backImageRef = image.cgImage?.cropping(to: CGRect(x: 0, y: 0, width: image.size.width * UIScreen.main.scale, height: image.size.height / 2 * UIScreen.main.scale))
        }

        backLayer.contents = backImageRef
    }
}
