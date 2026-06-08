package com.buzzvil

import com.facebook.react.bridge.ReactApplicationContext

class BuzzvilModule(reactContext: ReactApplicationContext) :
  NativeBuzzvilSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeBuzzvilSpec.NAME
  }
}
