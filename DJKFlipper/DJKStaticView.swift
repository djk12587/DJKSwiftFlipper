//
//  StaticView.swift
//  PageFlipper
//
//  Created by Daniel Koza on 10/2/14.
//  Copyright (c) 2014 Daniel Koza. All rights reserved.
//

import UIKit

class DJKStaticView: CATransformLayer {
    enum ImageSide {
        case left, right, top, bottom
    }

    fileprivate var flipOrientation: FlipOrientation
    lazy var leftOrTopSide: CALayer = {
        var lSide = CALayer(layer: self)
        var frame = self.bounds
        if self.flipOrientation == .horizontal {
            frame.size.width = frame.size.width / 2
            frame.origin.x = 0
        } else {
            frame.size.height = frame.size.height / 2
            frame.origin.y = 0
        }
        lSide.frame = frame
        lSide.contentsScale = UIScreen.main.scale
        lSide.backgroundColor = UIColor.black.cgColor

        return lSide
    }()

    lazy var rightOrBottomSide: CALayer = {
        var rSide = CALayer(layer: self)
        var frame = self.bounds
        if self.flipOrientation == .horizontal {
            frame.size.width = frame.size.width / 2
            frame.origin.x = frame.size.width
        } else {
            frame.size.height = frame.size.height / 2
            frame.origin.y = frame.size.height
        }
        rSide.frame = frame
        rSide.contentsScale = UIScreen.main.scale
        rSide.backgroundColor = UIColor.black.cgColor
        
        return rSide
    }()

    init(frame: CGRect, flipOrientation: FlipOrientation) {
        self.flipOrientation = flipOrientation
        super.init()
        
        self.frame = frame
        addSublayer(leftOrTopSide)
        addSublayer(rightOrBottomSide)
        zPosition = -1_000_000
    }
    
    required init?(coder aDecoder: NSCoder) {
        flipOrientation = .horizontal
        super.init(coder: aDecoder)
        self.addSublayer(leftOrTopSide)
        self.addSublayer(rightOrBottomSide)
    }
    
    func updateFrame(_ newFrame: CGRect) {
        self.frame = newFrame
        updatePageLayerFrames(newFrame)
    }

    fileprivate func updatePageLayerFrames(_ newFrame: CGRect) {
        var frame = newFrame

        if flipOrientation == .horizontal {
            frame.size.width = frame.size.width / 2
            leftOrTopSide.frame = frame
            
            frame.origin.x = frame.size.width
            rightOrBottomSide.frame = frame
        } else {
            frame.size.height = frame.size.height / 2
            leftOrTopSide.frame = frame
            
            frame.origin.y = frame.size.height
            rightOrBottomSide.frame = frame
        }
    }
    
    func set(image: UIImage, forSide imageSide: ImageSide) {
        let setSideContent: () -> Void
        switch imageSide {
        case .left:
            let imageReference = image.cgImage?.cropping(to: CGRect(x: 0, y: 0, width: image.size.width / 2 * UIScreen.main.scale, height: image.size.height * UIScreen.main.scale))
            setSideContent = { self.leftOrTopSide.contents = imageReference }
        case .right:
            let imageReference = image.cgImage?.cropping(to: CGRect(x: image.size.width / 2 * UIScreen.main.scale, y: 0, width: image.size.width / 2 * UIScreen.main.scale, height: image.size.height * UIScreen.main.scale))
            setSideContent = { self.rightOrBottomSide.contents = imageReference }
        case .top:
            let imageReference = image.cgImage?.cropping(to: CGRect(x: 0, y: 0, width: image.size.width * UIScreen.main.scale, height: image.size.height / 2 * UIScreen.main.scale))
            setSideContent = { self.leftOrTopSide.contents = imageReference }
        case .bottom:
            let imageReference = image.cgImage?.cropping(to: CGRect(x: 0, y: image.size.height / 2 * UIScreen.main.scale, width: image.size.width * UIScreen.main.scale, height: image.size.height / 2 * UIScreen.main.scale))
            setSideContent = { self.rightOrBottomSide.contents = imageReference }
        }
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        setSideContent()
        CATransaction.commit()
    }
}
