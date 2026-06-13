#import <UIKit/UIKit.h>

#ifndef BuzzFlexAdHost_h
#define BuzzFlexAdHost_h

NS_ASSUME_NONNULL_BEGIN

@class BuzzFlexAdHost;

// Callbacks forwarded from the SDK's BuzzFlexDelegate, flattened to the JS
// event surface (code/message extracted from the NSError). No SDK types leak
// through this protocol so the Fabric view never imports the SDK header.
@protocol BuzzFlexAdHostDelegate <NSObject>
- (void)flexAdHostDidLoad:(BuzzFlexAdHost *)host;
- (void)flexAdHost:(BuzzFlexAdHost *)host didFailWithCode:(NSString *)code message:(NSString *)message;
- (void)flexAdHostDidClick:(BuzzFlexAdHost *)host;
@end

// A UIView that wraps the SDK's BuzzFlexAdView (which is ALSO named
// `BuzzFlexAdView` — a duplicate-interface collision with the RN Fabric class
// of the same name). This helper isolates the SDK import to its own
// translation unit (BuzzFlexAdHost.mm); the Fabric view imports only this
// header, which vends a plain UIView + a no-SDK-types delegate. Mirrors
// BuzzBannerAdHost.
@interface BuzzFlexAdHost : UIView

@property (nonatomic, weak, nullable) id<BuzzFlexAdHostDelegate> adDelegate;

// Creates the SDK BuzzFlex(unitId:) controller + BuzzFlexAdView, applies
// `primaryColor` if non-nil, and calls load(). `bind()` is performed
// internally on success via the Swift shim (BuzzFlexAdBinder).
- (void)requestAdWithUnitId:(NSString *)unitId primaryColor:(nullable UIColor *)primaryColor;

// Tears down the ad (stops impressions / billing). Safe to call repeatedly.
- (void)removeAd;

@end

NS_ASSUME_NONNULL_END

#endif /* BuzzFlexAdHost_h */
