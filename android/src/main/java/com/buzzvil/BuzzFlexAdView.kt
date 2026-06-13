package com.buzzvil

import android.widget.FrameLayout
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

// Buzzvil FlexAd API, verified against the resolved buzzad-benefit-base 6.7.x
// AAR via `javap` (transitive through buzzvil-sdk / buzzvil-bom).
// BuzzFlexAdView is self-contained (inflates its own layout, manages its own
// attach/detach lifecycle) — unlike BuzzNative, no external resume/pause wiring
// is needed.
import com.buzzvil.buzzbenefit.BuzzAdError
import com.buzzvil.buzzbenefit.flexad.BuzzFlex
import com.buzzvil.buzzbenefit.flexad.BuzzFlexAdView as SdkBuzzFlexAdView

class BuzzFlexAdView(
  context: ThemedReactContext,
) : FrameLayout(context) {
  // Plain private fields + explicit setters. Do NOT use `var x; private set` —
  // its generated setX would clash with the fun setX below.
  private var unitId: String? = null
  private var primaryColor: Int? = null

  @Volatile private var disposed = false

  private var flex: BuzzFlex? = null

  // The unitId the in-flight / loaded ad was requested with. Doubles as the
  // reload guard: an in-place prop change must re-request (mirrors
  // BuzzBannerView's `loadedKey`). Cleared in cleanup() so a recycled view can
  // load again — never latched permanently.
  private var loadedUnitId: String? = null

  fun setUnitId(id: String) {
    unitId = id.ifEmpty { null }
  }

  fun setPrimaryColor(color: Int?) {
    primaryColor = color
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    loadIfReady()
  }

  // Fabric sets props in any order, and the view may not be attached when
  // unitId arrives. (Re)load only when a non-null unitId is present, the view
  // is attached, and the unitId actually changed — so an in-place prop change
  // on a mounted view reloads instead of being ignored (mirrors
  // BuzzvilNativeAdView / BuzzBannerView).
  internal fun loadIfReady() {
    val id = unitId ?: return
    if (!isAttachedToWindow) return
    if (id == loadedUnitId) return
    loadedUnitId = id

    teardown()
    disposed = false

    val sdkAdView = SdkBuzzFlexAdView(context, null)
    val buzzFlex = BuzzFlex(id)
    flex = buzzFlex

    primaryColor?.let { buzzFlex.setPrimaryColor(it) }

    buzzFlex.setListener(
      object : BuzzFlex.Listener {
        override fun onSuccess() {
          if (disposed) return
          sdkAdView.bind(buzzFlex)
          emit("topLoaded", Arguments.createMap())
        }

        override fun onFailure(error: BuzzAdError) {
          if (disposed) return
          val payload = Arguments.createMap()
          payload.putString("code", error.type.name)
          payload.putString("message", error.message ?: error.type.name)
          emit("topFailed", payload)
        }

        override fun onClicked() {
          if (disposed) return
          emit("topClicked", Arguments.createMap())
        }
      },
    )

    addView(
      sdkAdView,
      FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT,
      ),
    )

    buzzFlex.load()
  }

  private fun teardown() {
    flex?.dispose()
    flex = null
    removeAllViews()
  }

  private fun emit(
    eventName: String,
    payload: WritableMap,
  ) {
    val reactContext = context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id) ?: return
    dispatcher.dispatchEvent(BuzzFlexAdEvent(surfaceId, id, eventName, payload))
  }

  fun cleanup() {
    disposed = true
    teardown()
    // Clear the reload guard for recycle symmetry: a reused view must load again.
    loadedUnitId = null
  }

  private class BuzzFlexAdEvent(
    surfaceId: Int,
    viewTag: Int,
    private val name: String,
    private val payload: WritableMap,
  ) : Event<BuzzFlexAdEvent>(surfaceId, viewTag) {
    override fun getEventName() = name

    override fun getEventData() = payload
  }
}
