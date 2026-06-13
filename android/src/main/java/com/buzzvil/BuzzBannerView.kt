package com.buzzvil

import android.widget.FrameLayout
import com.facebook.react.uimanager.ThemedReactContext

// Stub: stores props only. The real BuzzBanner SDK load/bind lands in a later
// task; for now this keeps the generated Fabric interface satisfied and both
// builds green.
class BuzzBannerView(
  context: ThemedReactContext,
) : FrameLayout(context) {
  private var placementId: String? = null
  private var size: String = "W320XH50"

  fun setPlacementId(id: String) {
    placementId = id.ifEmpty { null }
  }

  fun setSize(v: String) {
    size = v
  }
}
