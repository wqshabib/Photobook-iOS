//
//  Modified MIT License
//
//  Copyright (c) 2010-2018 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The software MAY ONLY be used with the Kite Tech Ltd platform and MAY NOT be modified
//  to be used with any competitor platforms. This means the software MAY NOT be modified
//  to place orders with any competitors to Kite Tech Ltd, all orders MUST go through the
//  Kite Tech Ltd platform servers.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit
import Photobook

struct AssetPickerNotificationName {
    static let assetPickerAddedAssets = Notification.Name("ly.kite.photobook.assetPickerAddedAssetsNotificationName")
}

protocol Collectable {
    var collectorMode: AssetCollectorMode { get set }
    var selectedAssetsManager: SelectedAssetsManager! { get set }
    var addingDelegate: PhotobookAssetAddingDelegate? { get set }
}

class ModalAlbumsCollectionViewController: UIViewController, PhotobookAssetPicker {

    private struct Constants {
        static let topMargin: CGFloat = 10.0
        static let borderCornerRadius: CGFloat = 10.0
        static let velocityToTriggerSwipe: CGFloat = 50.0
        static let velocityForFastDismissal: CGFloat = 1000.0
        static let screenThresholdToDismiss: CGFloat = 3.0 // A third of the height
    }
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var containerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerViewHeightConstraint: NSLayoutConstraint!
    
    private var pickerTabBarController: UITabBarController!
    private var downwardArrowButtons = [UIButton]()
    private var hasAppliedMask = false
    
    var collectorMode: AssetCollectorMode = .adding
    weak var addingDelegate: PhotobookAssetAddingDelegate?
    var selectedAssetsManager = SelectedAssetsManager()

    var album: Album?
    var albumManager: AlbumManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        containerViewBottomConstraint.constant = view.bounds.height
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if #available(iOS 11.0, *) {
            containerViewHeightConstraint.constant = view.bounds.height - Constants.topMargin - view.safeAreaInsets.top
        } else {
            containerViewHeightConstraint.constant = view.bounds.height - Constants.topMargin - UIApplication.shared.statusBarFrame.height
        }

        containerViewBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
            self.view.layoutIfNeeded()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !hasAppliedMask {
            let rect = CGRect(x: 0.0, y: 0.0, width: view.bounds.width, height: view.bounds.height * 1.1)
            let cornerRadii = CGSize(width: Constants.borderCornerRadius, height: Constants.borderCornerRadius)
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: cornerRadii).cgPath
            let maskLayer = CAShapeLayer()
            maskLayer.fillColor = UIColor.white.cgColor
            maskLayer.frame = rect
            maskLayer.path = path
            containerView.layer.mask = maskLayer
            
            hasAppliedMask = true
        }
        downwardArrowButtons.forEach { $0.center = CGPoint(x: view.center.x, y: 20.0) }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EmbeddedNavigationController" {
            pickerTabBarController = (segue.destination as! UITabBarController)
            
            if !PhotobookManager.shared.storiesTabAvailable {
                pickerTabBarController.viewControllers?.remove(at: PhotobookManager.Tab.stories.rawValue)
            }
            
            for (index, viewController) in pickerTabBarController.viewControllers!.enumerated() {
                let rootNavigationController = viewController as! UINavigationController
                rootNavigationController.delegate = self
                
                let navigationBar = rootNavigationController.navigationBar as! PhotobookNavigationBar
                navigationBar.willShowPrompt = true
                
                downwardArrowButtons.append(UIButton(type: .custom))
                downwardArrowButtons[index].setImage(UIImage(named: "Drag-down-arrow"), for: .normal)
                downwardArrowButtons[index].setTitleColor(.black, for: .normal)
                downwardArrowButtons[index].sizeToFit()
                downwardArrowButtons[index].addTarget(self, action: #selector(didTapOnArrowButton(_:)), for: .touchUpInside)
                navigationBar.addSubview(downwardArrowButtons[index])
                
                let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPanOnNavigationBar(_:)))
                navigationBar.addGestureRecognizer(panGestureRecognizer)

                if var firstViewController = rootNavigationController.viewControllers.first as? Collectable {
                    firstViewController.collectorMode = collectorMode
                    firstViewController.selectedAssetsManager = selectedAssetsManager
                    firstViewController.addingDelegate = self
                }
            }
        }
    }
    
    @IBAction private func didSwipeOnNavigationBar(_ gesture: UISwipeGestureRecognizer) {
        animateContainerViewOffScreen()
    }
    
    @IBAction private func didPanOnNavigationBar(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let deltaY = gesture.translation(in: view).y
            if deltaY <= 0.0 {
                containerViewBottomConstraint.constant = Constants.topMargin
                return
            }
            containerViewBottomConstraint.constant = Constants.topMargin + deltaY
        case .ended:
            let deltaY = gesture.translation(in: view).y
            let velocityY = gesture.velocity(in: view).y
            
            let belowThreshold = deltaY >= view.bounds.height / Constants.screenThresholdToDismiss
            if  belowThreshold || velocityY > Constants.velocityToTriggerSwipe {
                let duration = belowThreshold || velocityY > Constants.velocityForFastDismissal ? 0.2 : 0.4
                animateContainerViewOffScreen(duration: duration) {
                    self.didFinishAdding(nil)
                }
                return
            }
            containerViewBottomConstraint.constant = Constants.topMargin
            UIView.animate(withDuration: 0.1, delay: 0.0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        default:
            break
        }
    }
    
    private func animateContainerViewOffScreen(duration: TimeInterval = 0.3, completionHandler: (() -> Void)? = nil) {
        containerViewBottomConstraint.constant = view.bounds.height
        UIView.animate(withDuration: duration, delay: 0.0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.view.backgroundColor = .clear
            self.view.layoutIfNeeded()
        }, completion: { _ in
            completionHandler?()
        })
    }
    
    @IBAction private func didTapOnArrowButton(_ sender: UIButton) {
        animateContainerViewOffScreen() {
            self.didFinishAdding(nil)
        }
    }
}

extension ModalAlbumsCollectionViewController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.prompt = " "
    }
}

extension ModalAlbumsCollectionViewController: PhotobookAssetAddingDelegate {
    
    func didFinishAdding(_ assets: [PhotobookAsset]?) {
        animateContainerViewOffScreen() {
            // Post notification for any selectedAssetManagers listening
            if let assets = assets {
                NotificationCenter.default.post(name: AssetPickerNotificationName.assetPickerAddedAssets, object: self, userInfo: ["assets": assets])
            }
            
            // Notify the delegate
            self.addingDelegate?.didFinishAdding(assets)
        }
    }
}

extension ModalAlbumsCollectionViewController: AssetPickerCollectionViewControllerDelegate {
    
    func viewControllerForPresentingOn() -> UIViewController? {
        return self
    }
    
}
