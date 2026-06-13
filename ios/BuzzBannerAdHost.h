#import <UIKit/UIKit.h>

#ifndef BuzzBannerAdHost_h
#define BuzzBannerAdHost_h

NS_ASSUME_NONNULL_BEGIN

@class BuzzBannerAdHost;

// Callbacks forwarded from the SDK's BuzzBannerViewDelegate, flattened to the
// JS event surface (code/message extracted from the NSError). No SDK types leak
// through this protocol so the Fabric view never imports the SDK header.
@protocol BuzzBannerAdHostDelegate <NSObject>
- (void)bannerAdHostDidLoad:(BuzzBannerAdHost *)host;
- (void)bannerAdHost:(BuzzBannerAdHost *)host didFailWithCode:(NSString *)code message:(NSString *)message;
- (void)bannerAdHostDidClick:(BuzzBannerAdHost *)host;
@end

// A UIView that wraps the SDK's BuzzBannerView (which is ALSO named
// `BuzzBannerView` — a duplicate-interface collision with the RN Fabric class of
// the same name). This helper isolates the SDK import to its own translation
// unit (BuzzBannerAdHost.mm); the Fabric view imports only this header, which
// vends a plain UIView + a no-SDK-types delegate. Mirrors the role Kotlin's
// `import ... as SdkBuzzBannerView` alias plays on Android.
@interface BuzzBannerAdHost : UIView

@property (nonatomic, weak, nullable) id<BuzzBannerAdHostDelegate> adDelegate;

// Builds the BuzzBannerConfig (mapping `size`), applies it via
// setConfigWithRootViewController:config:, and requests the ad. No-op if
// rootViewController is nil. `size`: 'W320XH50' | 'W320XH100' (unknown ->
// W320XH50 per the JS spec contract).
- (void)requestAdWithPlacementId:(NSString *)placementId
                            size:(NSString *)size
              rootViewController:(UIViewController *)rootViewController;

// Tears down the banner (stops impressions / billing). Safe to call repeatedly.
- (void)removeAd;

@end

NS_ASSUME_NONNULL_END

#endif /* BuzzBannerAdHost_h */
