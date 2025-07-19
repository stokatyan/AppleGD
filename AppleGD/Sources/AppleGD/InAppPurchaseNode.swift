//
//  InAppPurchaseNode.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/19/25.
//

import SwiftGodot
import StoreKit

@Godot
class InAppPurchaseNode: Node {
    
    @Signal var didFailToLoadAppProducts: SignalWithArguments<[String]>
    
    /**
     A signal that emits when products are loaded.
     - parameters:
        - products: A variant that holds an array of dictionaries representing the prodcut
     */
    @Signal var didLoadAppProducts: SignalWithArguments<VariantArray>
        
    @Callable(autoSnakeCase: true)
    func requestProducts(productIdentifiers: [String]) {
        let failureSignal = didFailToLoadAppProducts
        let successSignal = didLoadAppProducts
        Task {
            guard let appProducts = try? await Product.products(for: productIdentifiers) else {
                failureSignal.emit(productIdentifiers)
                return
            }
            
            var gProducts = VariantArray()
            
            
            for product in appProducts {
                let gProduct = GProduct()
                await gProduct.set(product: product)
                gProducts.append(gProduct.toVariant())
            }
            
            successSignal.emit(gProducts)
        }
        
    }
    
}

extension InAppPurchaseNode: @unchecked Sendable {}
