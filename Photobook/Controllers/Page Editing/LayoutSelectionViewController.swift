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

protocol LayoutSelectionDelegate: class {
    func didSelectLayout(_ layout: Layout)
}

protocol LayoutSelectionCollectionViewCellSetup {
    func setupLayout()
}

class LayoutSelectionViewController: UIViewController {

    private struct Constants {
        static let pageSideMargin: CGFloat = 20.0
        static let photobookSideMargin: CGFloat = 15.0
    }

    @IBOutlet private weak var collectionView: UICollectionView! {
        didSet {
            collectionView.backgroundView = nil
            collectionView.backgroundColor = .clear
            
            // Adapt the size of the cells to the book aspect ratio
            let aspectRatio = product.photobookTemplate.pageAspectRatio
            let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
            flowLayout.itemSize = CGSize(width: aspectRatio * flowLayout.itemSize.height + Constants.photobookSideMargin, height: flowLayout.itemSize.height)
        }
    }
    
    private var image: UIImage?
    private var oppositeImage: UIImage?
    
    var pageIndex: Int!
    var pageType: PageType!
    var asset: Asset? {
        didSet {
            guard let asset = asset else {
                image = nil
                collectionView.reloadData()
                return
            }
            
            let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
            asset.image(size: flowLayout.itemSize, loadThumbnailFirst: true, progressHandler: nil, completionHandler: { (image, error) in
                guard error == nil else {
                    print("Layouts: error retrieving image")
                    return
                }
                self.image = image
                self.collectionView?.reloadData()
            })
            
            if pageType == .left || pageType == .right {
                let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
                let oppositeIndex = pageIndex + (pageType == .left ? 1 : -1)
                let oppositeLayout = product.productLayouts[oppositeIndex]
                
                guard let oppositeAsset = oppositeLayout.asset else { return }
                
                oppositeAsset.image(size: flowLayout.itemSize, loadThumbnailFirst: true, progressHandler: nil, completionHandler: { (image, error) in
                    guard error == nil else {
                        print("Layouts: error retrieving opposite image")
                        return
                    }
                    self.oppositeImage = image
                    self.collectionView?.reloadData()
                })

            }
        }
    }
    private var oppositeAsset: Asset?
    
    var layouts: [Layout]! { didSet { collectionView?.reloadData() } }
    var coverColor: ProductColor! { didSet { collectionView.reloadData() } }
    var pageColor: ProductColor! { didSet { collectionView.reloadData() } }
    
    var selectedLayoutIndex = 0
    var selectedLayout: Layout! {
        didSet { selectedLayoutIndex = layouts.firstIndex(of: selectedLayout) ?? 0 }
    }
    var isEditingDoubleLayout = false
    weak var delegate: LayoutSelectionDelegate?
    
    private var product: PhotobookProduct! {
        return ProductManager.shared.currentProduct
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.reloadData()
        collectionView.scrollToItem(at: IndexPath(row: selectedLayoutIndex, section: 0), at: .centeredHorizontally, animated: true)
    }
    
    func accessibilityLayoutName(for layout: Layout, at indexPath: IndexPath) -> String {
        var imageDescription = ""
        if let imageLayoutBox = layout.imageLayoutBox {
            if imageLayoutBox.isSquareEnoughForVoiceOver() {
                imageDescription = NSLocalizedString("Accessibility/Editing/SquareImage", value: "Square Image", comment: "Accessibility label for a square image")
            } else if imageLayoutBox.isLandscape() {
                imageDescription = NSLocalizedString("Accessibility/Editing/LandscapeImage", value: "Landscape Image", comment: "Accessibility label for a landscape orientation image")
            } else {
                imageDescription = NSLocalizedString("Accessibility/Editing/PortraitImage", value: "Portrait Image", comment: "Accessibility label for a portrait orientation image")
            }
        }
        var layoutName = NSLocalizedString("Accessibility/Editing/LayoutSelection", value: "Layout \(indexPath.item + 1)", comment: "Accessibility label for the different page layouts. Example: Layout 1, Layout 2 etc") + ", "
        if layout.imageLayoutBox != nil && layout.textLayoutBox != nil {
            layoutName += NSLocalizedString("Accessibility/Editing/ImageAndTextLayout", value: "\(imageDescription) and Text", comment: "Accessibility label for a page layout that includes image and text")
        } else if layout.imageLayoutBox != nil {
            layoutName += NSLocalizedString("Accessibility/Editing/ImageOnlyLayout", value: "\(imageDescription) only", comment: "Accessibility label for a page layout that includes only an image.")
        } else if layout.textLayoutBox != nil {
            layoutName += NSLocalizedString("Accessibility/Editing/TextOnlyLayout", value: "Text only", comment: "Accessibility label for a page layout that includes only text.")
        } else {
            layoutName += NSLocalizedString("Accessibility/Editing/BlankLayout", value: "Blank", comment: "Accessibility label for a page layout that is blank.")
        }
        
        return layoutName
    }
}

extension LayoutSelectionViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return layouts != nil ? 1 : 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return layouts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let selected = indexPath.item == selectedLayoutIndex
        
        if pageType == .cover {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoverLayoutSelectionCollectionViewCell.reuseIdentifier, for: indexPath) as! CoverLayoutSelectionCollectionViewCell
            
            let layout = layouts[indexPath.item]
            cell.layout = layout
            cell.image = image // Pass the image to avoid reloading
            cell.asset = asset
            cell.isBorderVisible = selected
            cell.coverColor = coverColor
            
            cell.isAccessibilityElement = true
            cell.accessibilityHint = CommonLocalizedStrings.accessibilityDoubleTapToSelectListItem
            
            cell.accessibilityLabel = (selected ? CommonLocalizedStrings.accessibilityListItemSelected : "") + accessibilityLayoutName(for: layout, at: indexPath)
            
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LayoutSelectionCollectionViewCell.reuseIdentifier, for: indexPath) as! LayoutSelectionCollectionViewCell

        let layout = layouts[indexPath.item]
        cell.layout = layouts[indexPath.item]
        cell.pageIndex = pageIndex
        cell.image = image // Pass the image to avoid reloading
        cell.oppositeImage = oppositeImage
        cell.asset = asset
        cell.pageType = pageType
        cell.isBorderVisible = (indexPath.item == selectedLayoutIndex)
        cell.coverColor = coverColor
        cell.pageColor = pageColor
        cell.isEditingDoubleLayout = isEditingDoubleLayout
        
        cell.isAccessibilityElement = true
        cell.accessibilityHint = CommonLocalizedStrings.accessibilityDoubleTapToSelectListItem
        
        cell.accessibilityLabel = (selected ? CommonLocalizedStrings.accessibilityListItemSelected : "") + accessibilityLayoutName(for: layout, at: indexPath)

        return cell
    }
}

extension LayoutSelectionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.row != selectedLayoutIndex else { return }
        
        // Set border directly if visible, reload otherwise.
        let currentlySelectedIndexPath = IndexPath(row: selectedLayoutIndex, section: 0)
        if let currentlySelectedCell = collectionView.cellForItem(at: currentlySelectedIndexPath) as? BorderedCollectionViewCell {
            currentlySelectedCell.isBorderVisible = false
        } else {
            collectionView.reloadItems(at: [currentlySelectedIndexPath])
        }
        
        let newSelectedCell = collectionView.cellForItem(at: indexPath) as! BorderedCollectionViewCell
        newSelectedCell.isBorderVisible = true
        
        let layout = layouts[indexPath.row]
        selectedLayoutIndex = indexPath.row
        
        collectionView.scrollToItem(at: IndexPath(row: selectedLayoutIndex, section: 0), at: .centeredHorizontally, animated: true)
        delegate?.didSelectLayout(layout)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? LayoutSelectionCollectionViewCellSetup {
            cell.setupLayout()
        }
    }
}
