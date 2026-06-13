package com.buzzvil

import android.widget.FrameLayout
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

// Buzzvil BuzzBanner API. Class names / signatures verified against the resolved
// com.buzzvil:buzz-banner 6.7.6 AAR via `javap` (transitive through buzzvil-sdk /
// buzzvil-bom). Notably (confirmed in bytecode): setBuzzBannerConfig() only stores
// placementId + size and requests layout — the actual ad load is driven by
// BuzzBannerView.onResume(), which is wired through the RN host lifecycle below.
import com.buzzvil.buzzbanner.AdError
import com.buzzvil.buzzbanner.BuzzBanner
import com.buzzvil.buzzbanner.BuzzBannerConfig
import com.buzzvil.buzzbanner.BuzzBannerView as SdkBuzzBannerView
import com.buzzvil.buzzbanner.BuzzBannerViewListener

class BuzzBannerView(
  context: ThemedReactContext,
) : FrameLayout(context) {
  // Plain private fields + explicit setters. Do NOT use `var x; private set` —
  // its generated setX(String) would clash with the fun setX(String) below.
  private var placementId: String? = null
  private var size: String = "W320XH50"

  @Volatile private var disposed = false

  private var banner: SdkBuzzBannerView? = null
  private var lifecycleListener: LifecycleEventListener? = null

  // The (placementId, size) pair the in-flight / loaded banner was configured
  // with. Doubles as the reload guard: an in-place prop change must re-configure
  // and re-resume (mirrors BuzzvilNativeAdView's `loadedUnitId`). Cleared in
  // cleanup() so a recycled view can load again — never latched permanently.
  private var loadedKey: String? = null

  fun setPlacementId(id: String) {
    placementId = id.ifEmpty { null }
    loadIfReady()
  }

  fun setSize(v: String) {
    size = v
    loadIfReady()
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    loadIfReady()
  }

  // Map the friendly size string to the SDK enum. Unknown / sentinel values fall
  // back to W320XH50 (per the JS spec contract).
  private fun bannerSizeFor(v: String): BuzzBanner.BannerSize =
    when (v) {
      "W320XH50" -> BuzzBanner.BannerSize.W320XH50
      "W320XH100" -> BuzzBanner.BannerSize.W320XH100
      else -> BuzzBanner.BannerSize.W320XH50
    }

  // Fabric sets props in any order, and the view may not be attached when the
  // placementId arrives — every entry point calls this. Guard on a key comparison
  // (mirrors BuzzvilNativeAdView): (re)configure only when a non-null placementId
  // is present, the view is attached, and the (id,size) pair actually changed —
  // so an in-place prop change on a mounted view reloads instead of being ignored.
  private fun loadIfReady() {
    val id = placementId ?: return
    if (!isAttachedToWindow) return
    val key = "$id|$size"
    if (key == loadedKey) return
    loadedKey = key

    // Tear down any previous banner before the new load (mirrors cleanup()'s
    // teardown); a prop change on a mounted view reuses this same object.
    teardownBanner()
    // Re-arm the in-flight guard so the new banner's callbacks are not blocked by
    // a previous cleanup()/load.
    disposed = false

    val sdkBanner = SdkBuzzBannerView(context)
    banner = sdkBanner

    sdkBanner.setBuzzBannerConfig(
      BuzzBannerConfig
        .Builder()
        .placementId(id)
        .bannerSize(bannerSizeFor(size))
        .build(),
    )

    // Set the listener BEFORE onResume() so the load's callbacks land. AdError
    // exposes an int errorCode + String errorMessage (NOT the native-ad's
    // BuzzAdError.type.name) — stringify the code for the JS `code` field.
    sdkBanner.setBuzzBannerViewListener(
      object : BuzzBannerViewListener {
        override fun onLoaded() {
          if (disposed) return
          emit("topLoaded", Arguments.createMap())
        }

        override fun onFailed(error: AdError) {
          if (disposed) return
          val payload = Arguments.createMap()
          val code = error.errorCode.toString()
          payload.putString("code", code)
          payload.putString("message", error.errorMessage ?: code)
          emit("topFailed", payload)
        }

        override fun onClicked() {
          if (disposed) return
          emit("topClicked", Arguments.createMap())
        }
      },
    )

    // Pin the SDK banner to fill the host (mirrors iOS); default WRAP_CONTENT
    // would let the child collapse independently of the RN-driven host frame.
    addView(
      sdkBanner,
      FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT,
      ),
    )

    // LIFECYCLE GUARD: the banner needs Activity lifecycle to load and to stop
    // background impressions. RN's addLifecycleEventListener does NOT replay the
    // current state, so when this view mounts (host already RESUMED) onHostResume
    // will not fire on its own — the explicit onResume() below is the initial
    // load kick. Subsequent background→foreground cycles flow through the listener.
    val reactContext = context as ReactContext
    val listener =
      object : LifecycleEventListener {
        override fun onHostResume() {
          if (disposed) return
          banner?.onResume()
        }

        override fun onHostPause() {
          banner?.onPause()
        }

        override fun onHostDestroy() {
          banner?.onDestroy()
        }
      }
    lifecycleListener = listener
    reactContext.addLifecycleEventListener(listener)

    // Initial load kick (see note above). onResume() touches views — keep it on
    // the UI thread.
    UiThreadUtil.runOnUiThread {
      if (disposed) return@runOnUiThread
      banner?.onResume()
    }
  }

  private fun teardownBanner() {
    lifecycleListener?.let { (context as ReactContext).removeLifecycleEventListener(it) }
    lifecycleListener = null
    banner?.onDestroy()
    banner = null
    removeAllViews()
  }

  private fun emit(
    eventName: String,
    payload: WritableMap,
  ) {
    val reactContext = context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id) ?: return
    dispatcher.dispatchEvent(BuzzBannerEvent(surfaceId, id, eventName, payload))
  }

  fun cleanup() {
    disposed = true
    teardownBanner()
    // Clear the reload guard for recycle symmetry: a reused view must load again.
    loadedKey = null
  }

  private class BuzzBannerEvent(
    surfaceId: Int,
    viewTag: Int,
    private val name: String,
    private val payload: WritableMap,
  ) : Event<BuzzBannerEvent>(surfaceId, viewTag) {
    override fun getEventName() = name

    override fun getEventData() = payload
  }
}
