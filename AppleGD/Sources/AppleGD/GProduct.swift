//
//  GProduct.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/19/25.
//

import SwiftGodot
import StoreKit

enum GProductType: Int, CaseIterable {
    
    case unknown
    
    case autoRenewable
    case consumable
    case nonConsumable
    case nonRenewable
    
    init(type: Product.ProductType) {
        switch type {
        case .autoRenewable:
            self = GProductType.autoRenewable
        case .consumable:
            self = GProductType.consumable
        case .nonConsumable:
            self = GProductType.nonConsumable
        case .nonRenewable:
            self = GProductType.nonRenewable
        default:
            self = GProductType.unknown
        }
    }
}

@Godot
class GProduct: RefCounted {
    
    @Export var productId: String = ""
    @Export var productDescription: String = ""
    @Export var type: GProductType = .unknown
    
    @Export var isVerified: Bool = false
    @Export var displayName: String = ""
    @Export var displayPrice: String = ""
    @Export var price: Float = 0.0
    
    @Export var isFamilyShareable: Bool = false
    
    func set(product: Product) async {
        productId = product.id
        productDescription = product.description
        type = GProductType(type: product.type)
        
        if let entitlement = await product.currentEntitlement {
            switch entitlement {
            case .unverified(let signedType, let verificationError):
                isVerified = false
            case .verified(let signedType):
                isVerified = true
            }
        }

        displayName = product.displayName
        displayPrice = product.displayPrice
        price = Float(truncating: product.price as NSNumber)
        isFamilyShareable = product.isFamilyShareable
    }
}
