import BuzzAdBenefitSDK

// `BuzzFlexAdView.bind(_:)` (BuzzAdBenefitSDK) is a plain Swift method, not
// `@objc`, so it is unreachable from Obj-C++ directly — unlike `BuzzFlex` and
// `BuzzFlexAdView`'s designated initializer, which ARE `@objc`. This shim
// exposes just that one call.
@objc(BuzzFlexAdBinder)
public final class BuzzFlexAdBinder: NSObject {
  @MainActor @objc public static func bind(_ adView: BuzzFlexAdView, to flex: BuzzFlex) {
    adView.bind(flex)
  }
}
