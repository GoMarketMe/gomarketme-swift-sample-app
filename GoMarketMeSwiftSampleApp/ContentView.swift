import SwiftUI
import StoreKit
import GoMarketMe

struct ContentView: View {
    
    // Hold a strong reference to GoMarketMe
    @StateObject private var goMarketMe = GoMarketMe.shared
    
    @State private var isPurchased = false
    @State private var purchaseInProgress = false
    @State private var purchaseError: Error?
    @State private var isOfferCodeRedemptionPresented = false

    init() {
        goMarketMe.initialize(apiKey: "API_KEY") // Initialize with your API key
    }
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            Button(action: {
                Task {
                    await purchaseProduct()
                }
            }) {
                Text(purchaseInProgress ? "Purchasing..." : "Buy Test Product")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(purchaseInProgress)
            
            if let error = purchaseError {
                Text("Purchase failed: \(error.localizedDescription)")
                    .foregroundColor(.red)
            }
        
            if isPurchased {
                Text("Thank you for your purchase!")
                    .foregroundColor(.green)
            }
            
            VStack {
                
                // Note that the GoMarketMe SDK will only return the offerCode
                // if the attribution comes from an affiliate's QR code or short link.
                //
                // You might still want to display the redemption sheet for other scenarios
                // (e.g., if a user heard about the offer code on TikTok without clicking on an affiliate link).
                
                Button("Redeem Offer Code: \(goMarketMe.affiliateMarketingData?.offerCode ?? "NO_OFFER_CODE_FOUND")") {
                    // Show the offer code redemption sheet when the button is tapped
                    if #available(iOS 16.0, *) {
                        isOfferCodeRedemptionPresented = true
                    } else {
                        // Fallback for devices prior to iOS 16
                        if let offerCode = goMarketMe.affiliateMarketingData?.offerCode {
                            if let redemptionURL = redeemOfferCodeURL(for: offerCode) {
                                UIApplication.shared.open(redemptionURL)
                            }
                        }
                    }
                }
                .padding()
                .foregroundColor(.blue)
            }
        }
        .padding()
        // Present the offer code redemption sheet when `isOfferCodeRedemptionPresented` is true
        .offerCodeRedemption(isPresented: $isOfferCodeRedemptionPresented, onCompletion: { result in
            switch result {
            case .success:
                print("Offer code redeemed successfully.")
            case .failure(let error):
                print("Failed to redeem offer code: \(error.localizedDescription)")
            }
        })
    }
    
    // Function to generate redeem offer code URL for older iOS versions
    func redeemOfferCodeURL(for offerCode: String) -> URL? {
        // If supported, construct the redeem URL with the offer code
        if #available(iOS 16.0, *) {
            return nil // We're using the system redemption sheet for iOS 16+
        } else {
            return URL(string: "https://apps.apple.com/redeem/?ctx=offercodes&id=1234&code=\(offerCode)")
        }
    }
    // Function to handle in-app purchase
    @MainActor
    func purchaseProduct() async {
        purchaseInProgress = true
        purchaseError = nil

        do {
            // Step 1: Retrieve the product
            guard let product = try await Product.products(for: ["ProductID1"]).first else {
                print("Product not found")
                purchaseInProgress = false
                return
            }

            // Step 2: Attempt the purchase
            let result = try await product.purchase()

            // Step 3: Handle the purchase result
            switch result {
            case .success(let verification):
                // Verify the transaction
                if case .verified(let transaction) = verification {
                    // Update purchase status
                    isPurchased = true
                    print("Purchase successful for product ID: \(transaction.productID)")
                    await transaction.finish()
                    
                    // Sync the transaction (recommended)
                    
                    // Note: Use await goMarketMe.syncAllTransactions()
                    // if you don't have access to the transaction.
                    
                    await goMarketMe.syncTransaction(transaction: transaction)
                    
                } else {
                    print("Purchase verification failed")
                    throw NSError(domain: "Purchase", code: 0, userInfo: [NSLocalizedDescriptionKey: "Purchase verification failed"])
                }

            case .userCancelled:
                print("Purchase was cancelled by the user")

            case .pending:
                print("Purchase is pending")

            @unknown default:
                print("Unknown purchase state encountered")
                throw NSError(domain: "Purchase", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase state"])
            }

        } catch {
            print("Purchase failed: \(error.localizedDescription)")
            purchaseError = error
        }

        purchaseInProgress = false
    }

}

#Preview {
    ContentView()
}
