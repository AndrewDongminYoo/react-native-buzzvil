#import "BuzzBannerView.h"

#import "BuzzBannerAdHost.h"

#import <React/RCTUtils.h>

#import <react/renderer/components/BuzzvilSpec/ComponentDescriptors.h>
#import <react/renderer/components/BuzzvilSpec/EventEmitters.h>
#import <react/renderer/components/BuzzvilSpec/Props.h>
#import <react/renderer/components/BuzzvilSpec/RCTComponentViewHelpers.h>

using namespace facebook::react;

// IMPORTANT: this Fabric class is named `BuzzBannerView`, which collides with
// the SDK's own `BuzzBannerView` (a UIView). Obj-C has no import alias, so this
// file must NOT import the SDK header — all SDK interaction goes through
// `BuzzBannerAdHost` (a plain UIView in its own translation unit). See
// BuzzBannerAdHost.{h,mm}. Renaming the RN class is NOT an option: the generated
// provider registers the component by the runtime name `BuzzBannerView`.
@interface BuzzBannerView () <BuzzBannerAdHostDelegate>
@end

@implementation BuzzBannerView {
  BuzzBannerAdHost *_host;

  std::string _placementId;
  std::string _size;

  // The (placementId|size) pair the current banner was requested with. Doubles
  // as the reload guard: an in-place prop change must re-request (mirrors
  // Android's `loadedKey`). Cleared in prepareForRecycle so a recycled view can
  // load again — never latched permanently.
  std::string _loadedKey;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<BuzzBannerViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const BuzzBannerViewProps>();
    _props = defaultProps;

    _host = [[BuzzBannerAdHost alloc] initWithFrame:frame];
    _host.adDelegate = self;
    self.contentView = _host;
  }

  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<BuzzBannerViewProps const>(props);

  _placementId = newViewProps.placementId;
  _size = newViewProps.size;

  [self loadIfReady];

  [super updateProps:props oldProps:oldProps];
}

// Fabric may deliver props in any order / re-deliver them; (re)request only when
// a non-empty placementId is present, the view is in a window, and the (id,size)
// pair actually changed — so an in-place prop change reloads instead of being
// ignored (mirrors Android's isAttachedToWindow + loadedKey guard).
- (void)loadIfReady
{
  if (_placementId.empty()) {
    return;
  }
  // Window gate (mirrors Android's `if (!isAttachedToWindow) return`):
  // requestAd before the view is in a window can fire impressions against a
  // view that has no frame yet. didMoveToWindow will re-call loadIfReady when
  // the view attaches, so deferring here is correct.
  if (self.window == nil) {
    return;
  }
  std::string key = _placementId + "|" + _size;
  if (key == _loadedKey) {
    return;
  }
  _loadedKey = key;

  // Tear down any previous banner before the new request (mirrors
  // prepareForRecycle); a prop change on a mounted view reuses this same host.
  [_host removeAd];

  UIViewController *presenter = RCTPresentedViewController();
  if (presenter == nil) {
    // Edge case: view is in a non-key window, or the key window has no rootVC
    // yet. Clear the guard so a later prop re-delivery retries.
    _loadedKey.clear();
    return;
  }

  NSString *placementId = [NSString stringWithUTF8String:_placementId.c_str()];
  NSString *size = [NSString stringWithUTF8String:_size.c_str()];
  [_host requestAdWithPlacementId:placementId size:size rootViewController:presenter];
}

#pragma mark - Lifecycle

// First-load trigger when updateProps was delivered before the view had a
// window: loadIfReady gates on self.window, so we re-drive it from here.
// The key guard inside loadIfReady prevents a double-load on re-attach.
- (void)didMoveToWindow
{
  [super didMoveToWindow];
  if (self.window != nil) {
    [self loadIfReady];
  }
}

#pragma mark - Event emitter

- (const BuzzBannerViewEventEmitter &)eventEmitterRef
{
  return static_cast<const BuzzBannerViewEventEmitter &>(*_eventEmitter);
}

#pragma mark - BuzzBannerAdHostDelegate

- (void)bannerAdHostDidLoad:(BuzzBannerAdHost *)host
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onLoaded(BuzzBannerViewEventEmitter::OnLoaded{});
}

- (void)bannerAdHost:(BuzzBannerAdHost *)host didFailWithCode:(NSString *)code message:(NSString *)message
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onFailed(BuzzBannerViewEventEmitter::OnFailed{
      .code = std::string(code.UTF8String ?: ""),
      .message = std::string(message.UTF8String ?: "")});
}

- (void)bannerAdHostDidClick:(BuzzBannerAdHost *)host
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onClicked(BuzzBannerViewEventEmitter::OnClicked{});
}

#pragma mark - Recycling

- (void)prepareForRecycle
{
  // Clearing _loadedKey is the recycle guard: a reused view must request again.
  // removeAd stops the previous banner's impressions / billing.
  [_host removeAd];
  _loadedKey.clear();
  _placementId.clear();
  _size.clear();

  [super prepareForRecycle];
}

@end
