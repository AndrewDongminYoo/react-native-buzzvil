#import "BuzzBannerAdHost.h"

// SDK import isolated to THIS translation unit. BuzzAdBenefitSDK vends
// `BuzzBannerView` / `BuzzBannerConfig` / `BuzzBannerSize` /
// `BuzzBannerViewDelegate` (verified against the installed framework's generated
// -Swift.h, BuzzAdBenefitSDK 6.7.5). Same direct-from-Obj-C++ import the
// TurboModule (`Buzzvil.mm`) uses. Note: the SDK's `BuzzBannerView` is a UIView
// whose name collides with our RN Fabric class of the same name — keeping this
// import out of BuzzBannerView.mm is the whole reason this host file exists.
#import <BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>

@interface BuzzBannerAdHost () <BuzzBannerViewDelegate>
@end

@implementation BuzzBannerAdHost {
  BuzzBannerView *_banner;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    // The SDK banner is allocated per request (see requestAdWith…), mirroring
    // Android's fresh-SdkBuzzBannerView-per-load: re-configuring a banner after
    // removeAd is not a contract the headers express, so a clean instance avoids
    // relying on it.
  }
  return self;
}

// Map the friendly size string to the SDK enum. Unknown / sentinel values fall
// back to W320h50 (per the JS spec contract). `Dynamic` is intentionally not
// exposed by the JS spec, so it is unreachable here.
- (BuzzBannerSize)bannerSizeForString:(NSString *)size
{
  if ([size isEqualToString:@"W320XH100"]) {
    return BuzzBannerSizeW320h100;
  }
  return BuzzBannerSizeW320h50;
}

- (void)requestAdWithPlacementId:(NSString *)placementId
                            size:(NSString *)size
              rootViewController:(UIViewController *)rootViewController
{
  if (rootViewController == nil) {
    return;
  }

  // Fresh SDK banner per request (mirrors Android). Tear down + replace any
  // previous one so an in-place reconfigure (size / placement change) starts
  // clean instead of re-configuring a used banner.
  [self removeAd];

  BuzzBannerView *banner = [[BuzzBannerView alloc] initWithFrame:CGRectZero];
  banner.delegate = self;
  banner.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:banner];
  [NSLayoutConstraint activateConstraints:@[
    [banner.topAnchor constraintEqualToAnchor:self.topAnchor],
    [banner.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [banner.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [banner.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
  ]];
  _banner = banner;

  BuzzBannerSize bannerSize = [self bannerSizeForString:size];
  // The SDK uses a block-style builder (`+configWith:`), NOT a fluent
  // `.Builder()` chain. The block hands a BuzzBannerConfigBuilder with settable
  // `placementId` / `size` properties.
  BuzzBannerConfig *config = [BuzzBannerConfig configWith:^(BuzzBannerConfigBuilder *builder) {
    builder.placementId = placementId;
    builder.size = bannerSize;
  }];

  [_banner setConfigWithRootViewController:rootViewController config:config];
  [_banner requestAd];
}

- (void)removeAd
{
  [_banner removeAd];
  [_banner removeFromSuperview];
  _banner.delegate = nil;
  _banner = nil;
}

#pragma mark - BuzzBannerViewDelegate

- (void)bannerView:(BuzzBannerView *)bannerView didLoadApid:(NSString *)didLoadApid
{
  [self.adDelegate bannerAdHostDidLoad:self];
}

- (void)bannerView:(BuzzBannerView *)bannerView didFailApid:(NSString *)didFailApid error:(NSError *)error
{
  // Banner parity with Android (BuzzBannerView.kt): emit the NUMERIC error code
  // stringified (NOT the native-ad path's symbolic UPPER_SNAKE name), with the
  // localized description as the message (fallback to the code).
  NSString *code = [@(error.code) stringValue];
  // The SDK's localizedDescription can be terse (e.g. "exception"); append the
  // error domain + code so the JS `message` is self-describing in logs. The bare
  // numeric `code` field is preserved for programmatic handling.
  NSString *description = error.localizedDescription.length > 0 ? error.localizedDescription : @"unknown error";
  NSString *message = [NSString stringWithFormat:@"%@ (domain=%@, code=%@)", description, error.domain, code];
  [self.adDelegate bannerAdHost:self didFailWithCode:code message:message];
}

- (void)bannerView:(BuzzBannerView *)bannerView didClickApid:(NSString *)didClickApid
{
  [self.adDelegate bannerAdHostDidClick:self];
}

- (void)bannerView:(BuzzBannerView *)bannerView didRemoveApid:(NSString *)didRemoveApid
{
  // No matching JS event (mirrors the sibling's onParticipated no-op).
}

@end
