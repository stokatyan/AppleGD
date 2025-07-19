//
//  InAppPurchaseNode.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/19/25.
//

import SwiftGodot
import StoreKit

@Godot
class StoreKitNode: Node {
    
    private let kPendingPurchaseSet = "kPendingPurchaseSet"
    
    private var idToProductMap = [String: Product]()
    
    /**
     A signal that emits when a product purchase is completed.
     - parameters:
        - product: The id of the product that was successfuly purchased.
        - verificationResult: `true` iff StoreKit was able to verify the purchase.
     */
    @Signal var didCompleteProductPurchase: SignalWithArguments<String, Bool>
    
    /**
     A signal that emits when a product purchase is canceled.
     - parameters:
        - product: The id of the product purchase that was canceled.
     */
    @Signal var didCancelProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when a prodcut purchase is pending, which may result in a future signal regarding the state of the purchase.
     - parameters:
        - product: The id of the product that is pending.
     */
    @Signal var didCreatePendingProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when a product purchase failed.
     */
    @Signal var didFailToCompleteProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when a product purchase reaches an unkown state.
     */
    @Signal var didReachUnkownStateInProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when products fail to load.
     - parameters:
        - products: The array of productIds that failed to load.
     */
    @Signal var didFailToLoadAppProducts: SignalWithArguments<[String]>
    
    /**
     A signal that emits when products are loaded.
     - parameters:
        - products: A variant that holds an array of dictionaries representing the product.
     */
    @Signal var didLoadAppProducts: SignalWithArguments<VariantArray>
    
    @Callable(autoSnakeCase: true)
    func listenForTransactionUpdates() {
        let didCompletePurchase = didCompleteProductPurchase
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try result.payloadValue
                    let productId = transaction.productID
                    if getIsPurchasePending(id: productId) {
                        setIsPurchasePending(id: productId, isPending: false)
                        
                        if transaction.revocationDate == nil {
                            didCompletePurchase.emit(productId, true)
                        }
                    }
                    
                    await transaction.finish()
                    print("Transaction update received:", transaction)
                } catch {
                    print("Transaction update failed:", error)
                }
            }
        }
    }
        
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
                idToProductMap[product.id] = product
                
                let gProduct = GProduct()
                await gProduct.set(product: product)
                gProducts.append(gProduct.toVariant())
            }
            
            successSignal.emit(gProducts)
        }
    }
    
    @Callable(autoSnakeCase: true)
    func purchaseProduct(productId: String) {
        guard let product = idToProductMap[productId] else {
            return
        }
        
        let didCancelPurchase = didCancelProductPurchase
        let didCompletePurchase = didCompleteProductPurchase
        let didCreatePendingPurchase = didCreatePendingProductPurchase
        let didFailToCompletePurchase = didFailToCompleteProductPurchase
        let didReachUnkownState = didReachUnkownStateInProductPurchase
        
        Task {
            do {
                let result = await try product.purchase()
                switch result {
                case .success(let verificationResult):
                    switch verificationResult {
                    case .unverified:
                        didCompletePurchase.emit(productId, false)
                    case .verified:
                        didCompletePurchase.emit(productId, true)
                    }
                case .userCancelled:
                    didCancelProductPurchase.emit(productId)
                case .pending:
                    setIsPurchasePending(id: productId, isPending: true)
                    didCreatePendingPurchase.emit(productId)
                @unknown default:
                    didReachUnkownState.emit(productId)
                }
            } catch {
                didFailToCompletePurchase.emit(productId)
            }
        }
    }
    
    @Callable(autoSnakeCase: true)
    func requestReview() {
        #if os(iOS)
        Task { @MainActor in
            guard let window = ViewControllerPresenter.activeWindowScene else {
                return
            }
            AppStore.requestReview(in: window)
        }
        #endif
    }
    
    private func getIsPurchasePending(id: String) -> Bool {
        let array = UserDefaults.standard.stringArray(forKey: kPendingPurchaseSet) ?? []
        return array.contains { $0 == id }
    }
    
    private func setIsPurchasePending(id: String, isPending: Bool) {
        let array = UserDefaults.standard.stringArray(forKey: kPendingPurchaseSet) ?? []
        var set = Set(array)
        if isPending {
            set.insert(id)
        } else {
            set.remove(id)
        }
        
        let updatedArray = Array(set)
        UserDefaults.standard.set(set, forKey: kPendingPurchaseSet)
    }
}

extension StoreKitNode: @unchecked Sendable {}
