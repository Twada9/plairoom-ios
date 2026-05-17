import ComposableArchitecture
import GoogleMobileAds
import UIKit

struct RewardedAdClient: Sendable {
    var load: @Sendable () async -> Void
    var show: @Sendable () async -> Bool
}

extension RewardedAdClient: DependencyKey {
    static let liveValue: RewardedAdClient = {
        let box = RewardedAdBox()
        return RewardedAdClient(
            load: { await box.load() },
            show: { await box.show() }
        )
    }()
    
    static let testValue = RewardedAdClient(
        load: {},
        show: { true }
    )
}

extension DependencyValues {
    var rewardedAdClient: RewardedAdClient {
        get { self[RewardedAdClient.self] }
        set { self[RewardedAdClient.self] = newValue }
    }
}

private actor RewardedAdBox {
    private var rewardedAd: RewardedAd?
    private var isLoading = false
    var delegate: Delegate?

    func load() async {
        guard !isLoading, rewardedAd == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            rewardedAd = try await RewardedAd.load(
                with: "ca-app-pub-3940256099942544/1712485313",
                request: Request()
            )
            print("[Ad] load success")
        } catch {
            print("[Ad] load failed: \(error)")
        }
    }

    func show() async -> Bool {
        guard let ad = rewardedAd else {
            Task { await self.load() }
            return false
        }
        rewardedAd = nil
        let earned = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            Task { @MainActor in
                guard let root = Self.rootViewController() else {
                    return continuation.resume(returning: false)
                }

                let delegate = Delegate(continuation)
                await self.hold(delegate)
                ad.fullScreenContentDelegate = delegate

                ad.present(from: root) {
                    delegate.earned = true
                }
            }
        }
        Task { await self.load() }
        return earned
    }
    private func hold(_ d: Delegate) { self.delegate = d }
    
    @MainActor
    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?.rootViewController
    }
}


final class Delegate: NSObject, FullScreenContentDelegate {
    private var continuation: CheckedContinuation<Bool, Never>?
    var earned = false
    
    init(_ continuation: CheckedContinuation<Bool, Never>) {
        super.init()
        self.continuation = continuation
    }
    
    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        self.continuation?.resume(returning: false)
        self.continuation = nil
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        self.continuation?.resume(returning: self.earned)
        self.continuation = nil
    }
    
    private var addr: String {
        "\(Unmanaged.passUnretained(self).toOpaque())"
    }
}
