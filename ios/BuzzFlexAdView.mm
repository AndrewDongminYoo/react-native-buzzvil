#import "BuzzFlexAdView.h"

#import "BuzzFlexAdHost.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/BuzzvilSpec/ComponentDescriptors.h>
#import <react/renderer/components/BuzzvilSpec/EventEmitters.h>
#import <react/renderer/components/BuzzvilSpec/Props.h>
#import <react/renderer/components/BuzzvilSpec/RCTComponentViewHelpers.h>

using namespace facebook::react;

// IMPORTANT: this Fabric class is named `BuzzFlexAdView`, which collides with
// the SDK's own `BuzzFlexAdView` (a UIView). Obj-C has no import alias, so this
// file must NOT import the SDK header — all SDK interaction goes through
// `BuzzFlexAdHost` (a plain UIView in its own translation unit). See
// BuzzFlexAdHost.{h,mm}. Renaming the RN class is NOT an option: the generated
// provider registers the component by the runtime name `BuzzFlexAdView`.
@interface BuzzFlexAdView () <BuzzFlexAdHostDelegate>
@end

@implementation BuzzFlexAdView {
  BuzzFlexAdHost *_host;

  std::string _unitId;

  // The unitId the current ad was requested with. Doubles as the reload guard:
  // an in-place prop change must re-request (mirrors Android's `loadedUnitId`).
  // Cleared in prepareForRecycle so a recycled view can load again — never
  // latched permanently.
  std::string _loadedUnitId;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<BuzzFlexAdViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const BuzzFlexAdViewProps>();
    _props = defaultProps;

    _host = [[BuzzFlexAdHost alloc] initWithFrame:frame];
    _host.adDelegate = self;
    self.contentView = _host;
  }

  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<BuzzFlexAdViewProps const>(props);

  _unitId = newViewProps.unitId;

  // Commit props to _props BEFORE loadIfReady so that loadIfReady's read of
  // _props (for primaryColor) is always current — not the previous cycle's
  // value. This ordering matters on in-place unitId changes where the window
  // gate passes immediately (unlike the initial-mount path, where the gate
  // defers to didMoveToWindow by which time super has already run).
  [super updateProps:props oldProps:oldProps];

  [self loadIfReady];
}

// Fabric may deliver props in any order / re-deliver them; (re)request only
// when a non-empty unitId is present, the view is in a window, and the unitId
// actually changed — so an in-place prop change reloads instead of being
// ignored (mirrors Android's isAttachedToWindow + loadedUnitId guard).
- (void)loadIfReady
{
  if (_unitId.empty()) {
    return;
  }
  // Window gate (mirrors Android's `if (!isAttachedToWindow) return`):
  // load() before the view is in a window can fire impressions against a view
  // that has no frame yet. didMoveToWindow will re-call loadIfReady when the
  // view attaches, so deferring here is correct.
  if (self.window == nil) {
    return;
  }
  if (_unitId == _loadedUnitId) {
    return;
  }
  _loadedUnitId = _unitId;

  // Tear down any previous ad before the new request (mirrors
  // prepareForRecycle); a prop change on a mounted view reuses this same host.
  [_host removeAd];

  NSString *unitId = [NSString stringWithUTF8String:_unitId.c_str()];
  const auto &props = *std::static_pointer_cast<BuzzFlexAdViewProps const>(_props);
  UIColor *primaryColor = RCTUIColorFromSharedColor(props.primaryColor);
  [_host requestAdWithUnitId:unitId primaryColor:primaryColor];
}

#pragma mark - Lifecycle

// First-load trigger when updateProps was delivered before the view had a
// window: loadIfReady gates on self.window, so we re-drive it from here. The
// key guard inside loadIfReady prevents a double-load on re-attach.
- (void)didMoveToWindow
{
  [super didMoveToWindow];
  if (self.window != nil) {
    [self loadIfReady];
  }
}

#pragma mark - Event emitter

- (const BuzzFlexAdViewEventEmitter &)eventEmitterRef
{
  return static_cast<const BuzzFlexAdViewEventEmitter &>(*_eventEmitter);
}

#pragma mark - BuzzFlexAdHostDelegate

- (void)flexAdHostDidLoad:(BuzzFlexAdHost *)host
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onLoaded(BuzzFlexAdViewEventEmitter::OnLoaded{});
}

- (void)flexAdHost:(BuzzFlexAdHost *)host didFailWithCode:(NSString *)code message:(NSString *)message
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onFailed(BuzzFlexAdViewEventEmitter::OnFailed{
      .code = std::string(code.UTF8String ?: ""),
      .message = std::string(message.UTF8String ?: "")});
}

- (void)flexAdHostDidClick:(BuzzFlexAdHost *)host
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onClicked(BuzzFlexAdViewEventEmitter::OnClicked{});
}

#pragma mark - Recycling

- (void)prepareForRecycle
{
  // Clearing _loadedUnitId is the recycle guard: a reused view must request
  // again. removeAd stops the previous ad's impressions / billing.
  [_host removeAd];
  _loadedUnitId.clear();
  _unitId.clear();

  [super prepareForRecycle];
}

@end
