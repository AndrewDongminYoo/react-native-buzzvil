package com.buzzvil

import android.widget.FrameLayout
import com.facebook.react.uimanager.ThemedReactContext

class BuzzvilNativeAdView(context: ThemedReactContext) : FrameLayout(context) {
  // Plain private fields + explicit setters. Do NOT use `var x; private set` —
  // its generated setX(String) would clash with the fun setX(String) below.
  private var unitId: String? = null
  private var layoutVariant: String = "300x250"

  fun setUnitId(id: String) { unitId = id } // later tasks: trigger load
  fun setLayoutVariant(v: String) { layoutVariant = v } // later tasks: pick layout
}
