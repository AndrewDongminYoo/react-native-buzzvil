#import <BuzzvilSpec/BuzzvilSpec.h>

// Subclass the codegen base (not bare NSObject): NativeBuzzvilSpecBase provides
// setEventEmitterCallback: and the generated emitOnInterstitialClosed:, which
// the interstitial "closed" event is dispatched through.
@interface Buzzvil : NativeBuzzvilSpecBase <NativeBuzzvilSpec>

@end
