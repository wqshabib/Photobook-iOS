//
//  Photobook.swift
//  Photobook
//
//  Created by Jaime Landazuri on 17/11/2017.
//  Copyright © 2017 Kite.ly. All rights reserved.
//

import Foundation
import UIKit

// Defines the characteristics of a photobook / product
class Photobook: Codable {
    var id: Int
    var name: String!
    var aspectRatio: CGFloat!
    var coverLayouts: [Int]!
    var layouts: [Int]! // IDs of the permitted layouts
    
    // Does not include the cover asset
    var minimumRequiredAssets: Int! = 20 // TODO: Get this from somewhere
    
    // TODO: Currencies? MaximumAllowed Pages/Assets?
    
    init() {
        fatalError("Use parse(_:) instead")
    }
    
    private init(id: Int, name: String, aspectRatio: CGFloat, coverLayouts: [Int], layouts: [Int]) {
        self.id = id
        self.name = name
        self.aspectRatio = aspectRatio
        self.coverLayouts = coverLayouts
        self.layouts = layouts
    }

    // Parses a photobook dictionary.
    static func parse(_ dictionary: [String: AnyObject]) -> Photobook? {
        
        guard
            let id = dictionary["id"] as? Int,
            let name = dictionary["name"] as? String,
            let aspectRatio = dictionary["aspectRatio"] as? CGFloat, aspectRatio > 0.0,
            let coverLayouts = dictionary["coverLayouts"] as? [Int], coverLayouts.count > 0,
            let layouts = dictionary["layouts"] as? [Int], layouts.count > 0
        else { return nil }
        
        return Photobook(id: id, name: name, aspectRatio: aspectRatio, coverLayouts: coverLayouts, layouts: layouts)
    }    
}