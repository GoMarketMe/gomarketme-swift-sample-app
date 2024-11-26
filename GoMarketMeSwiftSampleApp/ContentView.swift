import SwiftUI
import StoreKit
import GoMarketMe

struct ContentView: View {
    
    // Hold a strong reference to GoMarketMe
    private let goMarketMe = GoMarketMe.shared

    @State private var isPurchased = false
    @State private var purchaseInProgress = false
    @State private var purchaseError: Error?

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
        }
        .padding()
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
