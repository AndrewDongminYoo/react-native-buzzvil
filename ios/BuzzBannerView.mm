#import "BuzzBannerView.h"

#import <react/renderer/components/BuzzvilSpec/ComponentDescriptors.h>
#import <react/renderer/components/BuzzvilSpec/EventEmitters.h>
#import <react/renderer/components/BuzzvilSpec/Props.h>
#import <react/renderer/components/BuzzvilSpec/RCTComponentViewHelpers.h>

using namespace facebook::react;

// Stub: reads props only. The real BuzzBanner SDK load/bind lands in a later
// task; for now this satisfies the generated Fabric component and keeps the
// build green.
@implementation BuzzBannerView {
  UIView *_container;

  std::string _placementId;
  std::string _size;
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

    _container = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView = _container;
  }

  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<BuzzBannerViewProps const>(props);

  _placementId = newViewProps.placementId;
  _size = newViewProps.size;

  [super updateProps:props oldProps:oldProps];
}

@end
