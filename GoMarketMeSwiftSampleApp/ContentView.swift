import SwiftUI
import StoreKit
import GoMarketMe

struct ContentView: View {
    @StateObject private var goMarketMe = GoMarketMe.shared

    @State private var isPurchased = false
    @State private var purchaseInProgress = false
    @State private var purchaseMessage: SampleMessage?
    @State private var syncInProgress = false
    @State private var syncMessage: SampleMessage?
    @State private var referralMessage: SampleMessage?
    @State private var isOfferCodeRedemptionPresented = false

    private let apiKey = "API_KEY"
    private let testProductID = "Subscription1"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                initializationSection
                referralCodeSection
                purchaseReportingSection
                programmaticDataSection
                appleOfferCodeSection
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            goMarketMe.initialize(apiKey: apiKey)
        }
        .offerCodeRedemption(
            isPresented: $isOfferCodeRedemptionPresented,
            onCompletion: handleOfferCodeRedemption
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("GoMarketMe Swift SDK", systemImage: "link.circle.fill")
                .font(.title.bold())
                .foregroundStyle(.tint)

            Text("Sample integration · SDK \(GoMarketMe.sdkVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var initializationSection: some View {
        SampleSection(
            badge: "Required",
            title: "Initialize",
            detail: "Initialize once when your app starts. Affiliate-link attribution is handled automatically."
        ) {
            HStack(spacing: 10) {
                ProgressView()
                    .opacity(goMarketMe.isInitializing ? 1 : 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(initializationTitle)
                        .font(.headline)
                    Text(initializationDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if goMarketMe.isInitialized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Initialized")
                }
            }
        }
    }

    private var referralCodeSection: some View {
        SampleSection(
            badge: "Optional",
            title: "Referral codes",
            detail: "Referral codes are the fallback when an affiliate link is not practical. Place this UI on the first screen users see after installing the app."
        ) {
            GoMarketMeReferralCodeTrigger(
                onResult: { data in
                    if let code = nonEmpty(data?.referralCode) {
                        referralMessage = .success("Referral code \(code) applied.")
                    } else if data != nil {
                        referralMessage = .info("This device is already attributed through an affiliate link.")
                    } else {
                        referralMessage = nil
                    }
                },
                onError: { error in
                    referralMessage = .error(error.localizedDescription)
                }
            )

            if let referralMessage {
                MessageView(message: referralMessage)
            }

            Text("The trigger text, colors, typography, and layout are configured in GoMarketMe.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var purchaseReportingSection: some View {
        SampleSection(
            badge: "Recommended",
            title: "Report purchases",
            detail: "GoMarketMe detects and reports purchases automatically. We also recommend manually syncing after your purchase provider confirms a successful transaction."
        ) {
            Button {
                Task { await syncPurchases() }
            } label: {
                Label(
                    syncInProgress ? "Syncing…" : "Manually sync purchases",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!goMarketMe.isInitialized || syncInProgress)

            if let syncMessage {
                MessageView(message: syncMessage)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("StoreKit test purchase")
                    .font(.headline)
                Text("Uses the sample product ID \(testProductID). After verification, the sample syncs with GoMarketMe before finishing the transaction.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await purchaseProduct() }
                } label: {
                    Label(
                        purchaseInProgress ? "Purchasing…" : "Buy test product",
                        systemImage: "cart"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(purchaseInProgress)
            }

            if isPurchased {
                MessageView(message: .success("Purchase completed and synced."))
            } else if let purchaseMessage {
                MessageView(message: purchaseMessage)
            }
        }
    }

    private var programmaticDataSection: some View {
        SampleSection(
            badge: "Optional",
            title: "Programmatic affiliate data",
            detail: "Use the initialization response to personalize onboarding, paywalls, offers, or other app content."
        ) {
            if let data = goMarketMe.affiliateMarketingData {
                KeyValueRow(label: "Attribution", value: attributionSource(for: data))
                KeyValueRow(label: "Affiliate ID", value: data.affiliate.id)
                KeyValueRow(label: "Campaign ID", value: data.campaign.id)
                KeyValueRow(
                    label: "Affiliate share",
                    value: data.saleDistribution.affiliatePercentage.isEmpty
                        ? "—"
                        : "\(data.saleDistribution.affiliatePercentage)%"
                )
                KeyValueRow(label: "Referral code", value: nonEmpty(data.referralCode) ?? "—")
                KeyValueRow(label: "Apple offer code", value: nonEmpty(data.offerCode) ?? "—")

                Text("This device is attributed. A referral code cannot replace the existing attribution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if goMarketMe.isInitialized {
                MessageView(
                    message: .info(
                        "No attribution is active. The referral-code trigger remains available as a fallback."
                    )
                )
            } else {
                Text("Affiliate data will appear after initialization.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appleOfferCodeSection: some View {
        SampleSection(
            badge: "iOS feature",
            title: "Apple offer codes",
            detail: "Apple subscription offer codes are separate from GoMarketMe referral codes. This opens Apple's redemption flow."
        ) {
            if let offerCode = nonEmpty(goMarketMe.affiliateMarketingData?.offerCode) {
                KeyValueRow(label: "Detected offer code", value: offerCode)
            } else {
                Text("No offer code was detected, but users can still enter one manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Apple offer-code redemption") {
                if #available(iOS 16.0, *) {
                    isOfferCodeRedemptionPresented = true
                } else if let offerCode = nonEmpty(goMarketMe.affiliateMarketingData?.offerCode),
                          let url = redeemOfferCodeURL(for: offerCode) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var initializationTitle: String {
        if goMarketMe.isInitializing { return "Initializing GoMarketMe…" }
        if goMarketMe.isInitialized { return "SDK ready" }
        return "Waiting to initialize"
    }

    private var initializationDetail: String {
        guard goMarketMe.isInitialized else {
            return "Calling GoMarketMe.shared.initialize(apiKey:)"
        }
        return goMarketMe.affiliateMarketingData == nil
            ? "Ready · no existing attribution"
            : "Ready · attribution loaded"
    }

    private func attributionSource(for data: GoMarketMeAffiliateMarketingData) -> String {
        if let code = nonEmpty(data.referralCode) {
            return "Referral code (\(code))"
        }
        return "Affiliate link"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func redeemOfferCodeURL(for offerCode: String) -> URL? {
        URL(string: "https://apps.apple.com/redeem/?ctx=offercodes&id=1234&code=\(offerCode)")
    }

    private func handleOfferCodeRedemption(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            print("Offer-code redemption flow completed.")
        case .failure(let error):
            print("Offer-code redemption failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func syncPurchases() async {
        syncInProgress = true
        defer { syncInProgress = false }

        let result = await goMarketMe.syncAllTransactions()
        if result.success {
            syncMessage = .success(
                "Synced \(result.sentCount) of \(result.fetchedCount) transaction(s)."
            )
        } else {
            syncMessage = .error(
                "Sync did not complete. \(result.failedCount) transaction(s) failed."
            )
        }
    }

    @MainActor
    private func purchaseProduct() async {
        purchaseInProgress = true
        purchaseMessage = nil
        isPurchased = false
        defer { purchaseInProgress = false }

        do {
            guard let product = try await Product.products(for: [testProductID]).first else {
                purchaseMessage = .error(
                    "Product \(testProductID) was not found. Check the sample StoreKit configuration."
                )
                return
            }

            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseMessage = .error("StoreKit could not verify the transaction.")
                    return
                }

                let syncResult = await goMarketMe.syncAllTransactions()
                await transaction.finish()

                if syncResult.success {
                    isPurchased = true
                } else {
                    purchaseMessage = .error("The purchase succeeded, but GoMarketMe sync failed.")
                }

            case .userCancelled:
                purchaseMessage = .info("Purchase cancelled.")
            case .pending:
                purchaseMessage = .info("Purchase pending approval.")
            @unknown default:
                purchaseMessage = .error("StoreKit returned an unknown purchase state.")
            }
        } catch {
            purchaseMessage = .error(error.localizedDescription)
        }
    }
}

private struct SampleSection<Content: View>: View {
    let badge: String?
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    init(
        badge: String? = nil,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) {
        self.badge = badge
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(.title3.bold())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

private struct SampleMessage {
    enum Kind {
        case info
        case success
        case error
    }

    let kind: Kind
    let text: String

    static func info(_ text: String) -> Self { Self(kind: .info, text: text) }
    static func success(_ text: String) -> Self { Self(kind: .success, text: text) }
    static func error(_ text: String) -> Self { Self(kind: .error, text: text) }
}

private struct MessageView: View {
    let message: SampleMessage

    var body: some View {
        Label(message.text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var color: Color {
        switch message.kind {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        }
    }

    private var icon: String {
        switch message.kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

#Preview {
    ContentView()
}
