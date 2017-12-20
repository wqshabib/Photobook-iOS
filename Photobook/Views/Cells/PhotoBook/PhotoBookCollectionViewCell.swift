//
//  PhotoBookCollectionViewCell.swift
//  Photobook
//
//  Created by Konstadinos Karayannis on 21/11/2017.
//  Copyright © 2017 Kite.ly. All rights reserved.
//

import UIKit

protocol PhotoBookCollectionViewCellDelegate: class {
    func didTapOnPlusButton(at foldIndex: Int)
}

class PhotoBookCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var bookView: PhotobookView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var leftPageView: PhotoBookPageView! {
        didSet {
            bookView.leftPageView = leftPageView
        }
    }
    @IBOutlet weak var rightPageView: PhotoBookPageView? {
        didSet {
            bookView.rightPageView = rightPageView
        }
    }
    @IBOutlet weak var widthConstraint: NSLayoutConstraint!
    @IBOutlet private var pageAspectRatioConstraint: NSLayoutConstraint!
    
    /* This hidden view is here only to set the aspect ratio of the page,
     because if the aspect ratio constraint is set to one of the non-hidden views,
     the automatic sizing of the cells doesn't work. I don't know why, it might be a bug
     in autolayout.
     */
    @IBOutlet private weak var aspectRatioHelperView: UIView!
    @IBOutlet weak var obscuringView: UIView!
    @IBOutlet weak var plusButton: UIButton!
    weak var delegate: PhotoBookCollectionViewCellDelegate?
    
    @IBAction func didTapPlus(_ sender: UIButton) {
        guard let productLayout = leftPageView.productLayout ?? rightPageView?.productLayout,
            let foldIndex = ProductManager.shared.foldIndex(for: productLayout)
            else { return }
        delegate?.didTapOnPlusButton(at: foldIndex)
    }
    
    func configurePageAspectRatio(_ ratio: CGFloat) {
        aspectRatioHelperView.removeConstraint(pageAspectRatioConstraint)
        pageAspectRatioConstraint = NSLayoutConstraint(item: aspectRatioHelperView, attribute: .width, relatedBy: .equal, toItem: aspectRatioHelperView, attribute: .height, multiplier: ratio, constant: 0)
        pageAspectRatioConstraint.priority = UILayoutPriority(750)
        aspectRatioHelperView.addConstraint(pageAspectRatioConstraint)
    }
    
    func setIsRearranging(_ isRearranging: Bool) {
        (bookView.interactions.first as? UIDragInteraction)?.isEnabled = isRearranging
        leftPageView.tapGesture.isEnabled = !isRearranging
        rightPageView?.tapGesture.isEnabled = !isRearranging
    }
}

class PhotobookView: UIView {
    weak var leftPageView: PhotoBookPageView!
    weak var rightPageView: PhotoBookPageView?
}
