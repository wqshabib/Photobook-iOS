//
//  TextEditingViewController.swift
//  Photobook
//
//  Created by Jaime Landazuri on 30/01/2018.
//  Copyright © 2018 Kite.ly. All rights reserved.
//

import UIKit

@objc protocol TextToolBarViewDelegate {
    func didSelectFontType(_ type: FontType)
}

class TextToolBarView: UIView {
    
    @IBOutlet private var toolButtons: [UIButton]! {
        didSet { toolButtons.first?.isSelected = true }
    }
    private var selectedIndex = 0
    
    weak var delegate: TextToolBarViewDelegate?
    
    @IBAction func tappedToolButton(_ sender: UIButton) {
        let index = toolButtons.index(of: sender)!
        guard selectedIndex != index else { return }

        toolButtons[selectedIndex].isSelected = false
        toolButtons[index].isSelected = true
        
        selectedIndex = index
        let fontType = FontType(rawValue: index)!
        delegate?.didSelectFontType(fontType)
    }
}

protocol TextEditingDelegate: class {
    
    func didChangeFontType(to fontType: FontType)
    func didChangeText(to text: String?)
    
}

class TextEditingViewController: UIViewController {

    private struct Constants {
        static let keyboardInitialBottomConstraint: CGFloat = 100.0
    }
    
    @IBOutlet private weak var textToolBarView: TextToolBarView! {
        didSet {
            textToolBarView.backgroundColor = UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1.0)
            textToolBarView.delegate = self
        }
    }
    @IBOutlet private weak var textViewBorderView: UIView!
    @IBOutlet private weak var textView: UITextView! {
        didSet { textView.delegate = self }
    }
    @IBOutlet private weak var pageView: UIView!
    @IBOutlet private weak var assetContainerView: UIView!
    @IBOutlet private weak var assetPlaceholderIconImageView: UIImageView!
    @IBOutlet private weak var assetImageView: UIImageView!
    
    @IBOutlet private weak var textViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var textViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var textViewBottomConstraint: NSLayoutConstraint!
    
    var productLayout: ProductLayout!
    var assetImage: UIImage?
    var pageColor: ProductColor!
    var initialContainerRect: CGRect?
    weak var delegate: TextEditingDelegate?

    private lazy var animatableAssetImageView = UIImageView()
    private var completionBlock: (() -> Void)?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.alpha = 0.0
        
        // FIXME: Move color to global scope
        textViewBorderView.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        textView.textContainer.lineFragmentPadding = 0.0
        textView.textContainerInset = .zero
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillShow, object: nil)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            // Code placed here animate along with the keyboard, hence the closure
            UIView.performWithoutAnimation {
                textViewBottomConstraint.constant = keyboardSize.height
                self.pageView.center = CGPoint(x: self.pageView.center.x, y: self.pageView.center.y - (keyboardSize.height - Constants.keyboardInitialBottomConstraint))
                self.performAnimations()
            }
        }
    }
    
    func animateOn(completion: @escaping () -> Void) {
        // Place views according to layout
        setup()
        
        completionBlock = completion
        textView.becomeFirstResponder()
    }
    
    private func performAnimations() {
        guard let initialContainerRect = initialContainerRect else { return }
        
        // Take a view snapshot and shrink it to the initial frame
        textViewBorderView.alpha = 0.0
        textView.alpha = 0.0
        
        let backgroundColor = view.backgroundColor
        view.backgroundColor = .clear
        pageView.layoutIfNeeded()
        
        animatableAssetImageView.transform = .identity
        animatableAssetImageView.frame = assetContainerView.frame
        animatableAssetImageView.image = assetContainerView.snapshot()
        animatableAssetImageView.center = CGPoint(x: initialContainerRect.midX, y: initialContainerRect.midY)
        
        assetContainerView.alpha = 0.0

        let targetRect = pageView.convert(assetContainerView.frame, to: view)
        let initialScale = initialContainerRect.width / targetRect.width
        animatableAssetImageView.transform = CGAffineTransform.identity.scaledBy(x: initialScale, y: initialScale)
        
        view.addSubview(animatableAssetImageView)
        view.alpha = 1.0
        
        // Re-enable animations
        UIView.setAnimationsEnabled(true)

        UIView.animate(withDuration: 0.1) {
            self.view.backgroundColor = backgroundColor
        }

        UIView.animate(withDuration: 0.2, delay: 0.1, options: [.curveEaseInOut], animations: {
            self.animatableAssetImageView.frame = targetRect
        }, completion: { _ in
            self.animatableAssetImageView.alpha = 0.0
            self.assetContainerView.alpha = 1.0

            UIView.animate(withDuration: 0.1) {
                self.textViewBorderView.alpha = 1.0
                self.textView.alpha = 1.0
            }
        })
    }
    
    func visibleTextInLayout() -> String? {
        return textView.visibleText
    }
    
    func animateOff() {
        guard let initialContainerRect = initialContainerRect else { return }
        
        animatableAssetImageView.alpha = 1.0
        assetContainerView.alpha = 0.0

        let backgroundColor = view.backgroundColor

        textView.alpha = 0.0
        textViewBorderView.alpha = 0.0

        UIView.animate(withDuration: 0.1, delay: 0.1, animations: {
            self.view.backgroundColor = .clear
        })

        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.animatableAssetImageView.frame = initialContainerRect
        }, completion: { _ in
            self.view.alpha = 0.0
            self.view.backgroundColor = backgroundColor
            if let completion = self.completionBlock { completion() }
        })
    }
    
    private func setup() {
        // Figure out the height of the textView
        guard
            let pageRatio = ProductManager.shared.product?.aspectRatio,
            let textLayoutBox = productLayout?.layout.textLayoutBox
        else {
            fatalError("Text editing failed due to missing layout info.")
        }
        
        textView.inputAccessoryView = textToolBarView
        textView.text = productLayout.text
        
        let aspectRatio = textLayoutBox.aspectRatio(forContainerRatio: pageRatio)
        textViewHeightConstraint.constant = textView.bounds.width / aspectRatio
        
        // Place it above the selectors to begin with
        textViewBottomConstraint.constant = Constants.keyboardInitialBottomConstraint
        
        // Position page and image box, if needed
        let layoutBoxSize = CGSize(width: textView.bounds.width, height: textViewHeightConstraint.constant)
        let pageSize = textLayoutBox.containerSize(for: layoutBoxSize)
        
        let topMargin = view.bounds.height - textViewBottomConstraint.constant - textViewHeightConstraint.constant
        let textLayoutBoxRect = textLayoutBox.rectContained(in: pageSize)
        let pageXCoordinate = textViewLeadingConstraint.constant - textLayoutBoxRect.minX
        let pageYCoordinate = topMargin - textLayoutBoxRect.minY
        
        pageView.frame.origin = CGPoint(x: pageXCoordinate, y: pageYCoordinate)
        pageView.frame.size = pageSize
        view.backgroundColor = pageColor.uiColor()
        
        // Set up the textField font
        let fontType: FontType
        if let productLayoutText = productLayout.productLayoutText {
            fontType = productLayoutText.fontType
        } else {
            fontType = .clear
        }
        setTextViewAttributes(with: fontType, fontColor: pageColor.fontColor())
        
        // Place image if needed
        guard let imageLayoutBox = productLayout!.layout.imageLayoutBox else {
            assetContainerView.alpha = 0.0
            return
        }
        assetContainerView.alpha = 1.0
        
        let imageLayoutRect = imageLayoutBox.rectContained(in: pageSize)
        assetContainerView.frame = imageLayoutRect

        guard let asset = productLayout?.asset,
              let image = assetImage else {
                setImagePlaceholder(visible: true)
                return
        }
        setImagePlaceholder(visible: false)
        
        assetImageView.image = image
        assetImageView.transform = .identity
        assetImageView.frame = CGRect(x: 0.0, y: 0.0, width: asset.size.width, height: asset.size.height)
        assetImageView.center = CGPoint(x: assetContainerView.bounds.midX, y: assetContainerView.bounds.midY)
        
        productLayout!.productLayoutAsset!.containerSize = assetContainerView.bounds.size
        assetImageView.transform = productLayout!.productLayoutAsset!.transform
    }
    
    private func onScreenFontSize(for fontType: FontType) -> CGFloat {
        let photobookToOnScreenScale = pageView.bounds.height / ProductManager.shared.product!.pageHeight
        return round(fontType.photobookFontSize() * photobookToOnScreenScale)
    }
    
    private func setImagePlaceholder(visible: Bool) {
        if visible {
            assetImageView.image = nil
            assetContainerView.backgroundColor = UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
            let iconSize = min(assetContainerView.bounds.width, assetContainerView.bounds.height)
            assetPlaceholderIconImageView.bounds.size = CGSize(width: iconSize * 0.1, height: iconSize * 0.1)
            assetPlaceholderIconImageView.center = CGPoint(x: assetContainerView.bounds.midX, y: assetContainerView.bounds.midY)
            assetPlaceholderIconImageView.alpha = 1.0
        } else {
            assetContainerView.backgroundColor = .clear
            assetPlaceholderIconImageView.alpha = 0.0
        }
    }

    private func setTextViewAttributes(with fontType: FontType, fontColor: UIColor) {
        let fontSize = onScreenFontSize(for: fontType)
        textView.attributedText = fontType.attributedText(with: textView.text, fontSize: fontSize, fontColor: fontColor)
        textView.typingAttributes = fontType.typingAttributes(fontSize: fontSize, fontColor: fontColor)
    }
    
    private func textGoesOverBounds(for textView: UITextView, string: String, range: NSRange) -> Bool {
        let viewHeight = textView.bounds.height
        let width = textView.textContainer.size.width
        
        let attributedString = NSMutableAttributedString(attributedString: textView.textStorage)
        attributedString.replaceCharacters(in: range, with: string)
        
        let textHeight = (attributedString as NSAttributedString).height(for: width)
        return textHeight >= viewHeight
    }
}

extension TextEditingViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        // Dismiss on line break
        guard text.rangeOfCharacter(from: CharacterSet.newlines) == nil else {
            textView.resignFirstResponder()
            delegate?.didChangeText(to: textView.text)
            return false
        }
        
        // Allow deleting
        if text.count == 0 { return true }
        
        // Disallow pasting non-ascii characters
        if !text.canBeConverted(to: String.Encoding.ascii) { return false }
        
        // Check that the new length doesn't exceed the textView bounds
        return !textGoesOverBounds(for: textView, string: text, range: range)
    }    
}

extension TextEditingViewController: TextToolBarViewDelegate {
    
    func didSelectFontType(_ fontType: FontType) {
        setTextViewAttributes(with: fontType, fontColor: pageColor.fontColor())
        
        delegate?.didChangeFontType(to: fontType)
    }
}
