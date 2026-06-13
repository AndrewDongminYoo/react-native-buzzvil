package com.buzzvil

import android.app.Application
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil

// The Buzzvil class names and import paths below are verified against the
// resolved `com.buzzvil:buzzvil-sdk` AAR (buzzvil-bom 6.7.x) — this module
// compiles cleanly via `:dongminyu_react-native-buzzvil:compileDebugKotlin`.
import com.buzzvil.buzzbanner.BuzzBanner
import com.buzzvil.buzzbenefit.BuzzBenefitConfig
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHub
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHubConfig
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHubPage
import com.buzzvil.buzzbenefit.BuzzAdError
import com.buzzvil.buzzbenefit.interstitial.BuzzInterstitial
import com.buzzvil.buzzbenefit.interstitial.BuzzInterstitialListener
import com.buzzvil.entrypoint.BuzzEntryPoint
import com.buzzvil.entrypoint.BuzzEntryPointType
import com.buzzvil.sdk.BuzzvilSdk
import com.buzzvil.sdk.BuzzvilSdkLoginListener
import com.buzzvil.sdk.BuzzvilSdkUser

class BuzzvilModule(
  reactContext: ReactApplicationContext,
) : NativeBuzzvilSpec(reactContext) {
  override fun initialize(
    appId: String,
    appSecret: String,
  ) {
    val application = reactApplicationContext.applicationContext as Application
    val config = BuzzBenefitConfig.Builder(appId).build()
    BuzzvilSdk.initialize(application, config)
    // BuzzBanner needs its own init or the banner view emits
    // onFailed(code="0", "BuzzBanner is not initialized."). The 3-arg init
    // (appId, appSecret, context) is the full one — it both stores the
    // credentials and builds the underlying ad SDK (verified via javap on
    // buzz-banner 6.7.6). Sentinel contract (see NativeBuzzvil.ts): "" appSecret
    // → skip BuzzBanner init (iOS has no separate banner init at all).
    if (appSecret.isNotEmpty()) {
      BuzzBanner().init(appId, appSecret, application)
    }
  }

  override fun login(
    userId: String,
    gender: String,
    birthYear: Double,
    promise: Promise,
  ) {
    // Sentinel contract (see NativeBuzzvil.ts): "" gender / 0 birthYear → unset.
    val user =
      BuzzvilSdkUser(
        userId = userId,
        gender =
          when (gender) {
            "MALE" -> BuzzvilSdkUser.Gender.MALE
            "FEMALE" -> BuzzvilSdkUser.Gender.FEMALE
            else -> BuzzvilSdkUser.Gender.UNKNOWN // sentinel "" → unspecified
          },
        birthYear = if (birthYear > 0) birthYear.toInt() else null,
      )
    BuzzvilSdk.login(
      user,
      object : BuzzvilSdkLoginListener {
        override fun onSuccess() {
          promise.resolve(null)
        }

        override fun onFailure(errorType: BuzzvilSdkLoginListener.ErrorType) {
          promise.reject("buzzvil_login_failed", "Buzzvil login failed: $errorType")
        }
      },
    )
  }

  override fun logout() {
    BuzzvilSdk.logout()
  }

  override fun isLoggedIn(promise: Promise) {
    promise.resolve(BuzzvilSdk.isLoggedIn)
  }

  override fun showBenefitHub(
    routePath: String,
    showHistory: Boolean,
    page: String,
  ) {
    // BenefitHub launches an Activity — must run on the main thread (parity
    // with the iOS dispatch_async(main) path).
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity ?: return@runOnUiThread
      val configBuilder = BuzzBenefitHubConfig.Builder()
      when (page) {
        "luckyBox" -> configBuilder.routePath(BuzzBenefitHubPage.LUCKY_BOX.toRoutePath())
        "missionPack" -> configBuilder.routePath(BuzzBenefitHubPage.MISSION_PACK.toRoutePath())
        "history" -> configBuilder.queryParams(BuzzBenefitHubPage.HISTORY.toRedirectQueryParams())
        else -> {
          if (routePath.isNotEmpty()) configBuilder.routePath(routePath)
          if (showHistory) configBuilder.queryParams(BuzzBenefitHubPage.HISTORY.toRedirectQueryParams())
        }
      }
      // An empty (default-built) config is equivalent to passing no config —
      // parity with the iOS `needsConfig` guard, which skips setConfig on the
      // all-sentinel path.
      BuzzBenefitHub.show(activity, configBuilder.build())
    }
  }

  // --- EntryPoint ---

  // EntryPoint needs no explicit init here: BuzzvilSdk.initialize wires up the
  // internal BuzzEntryPoint.init (which takes an internal DI component). iOS's
  // BuzzEntryPoint.shared is likewise ready post-init.
  override fun loadEntryPoints(promise: Promise) {
    BuzzEntryPoint.load(
      { types ->
        // Map by enum case name (NOT ordinal): the Android and iOS enum
        // orderings differ, so canonical string names are the only safe
        // cross-platform contract. See NativeBuzzvil.ts.
        val names = Arguments.createArray()
        types.forEach { names.pushString(it.toName()) }
        promise.resolve(names)
      },
      { error: BuzzAdError ->
        promise.reject("buzzvil_entrypoint_load_failed", error.message ?: error.type.name)
      },
    )
  }

  override fun showEntryPointPopup() {
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity ?: return@runOnUiThread
      BuzzEntryPoint.showPopup(activity)
    }
  }

  override fun showEntryPointBottomSheet() {
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity ?: return@runOnUiThread
      BuzzEntryPoint.showBottomSheet(activity)
    }
  }

  private fun BuzzEntryPointType.toName(): String =
    when (this) {
      BuzzEntryPointType.FAB -> "fab"
      BuzzEntryPointType.POPUP -> "popup"
      BuzzEntryPointType.BOTTOM_SHEET -> "bottomSheet"
      BuzzEntryPointType.BANNER -> "banner"
      BuzzEntryPointType.CUSTOM -> "custom"
    }

  // --- Interstitial ---

  // Design Decision 1: one BuzzInterstitial instance per unitId, so a later
  // showInterstitial(unitId) presents the instance loaded by loadInterstitial.
  private val interstitials = mutableMapOf<String, BuzzInterstitial>()

  override fun loadInterstitial(
    unitId: String,
    type: String,
    promise: Promise,
  ) {
    // Reject a new load while an instance for this unitId already exists — in
    // flight, loaded-and-waiting-to-show, or currently showing (parity with iOS).
    // Overwriting interstitials[unitId] would let the OLD instance's onAdClosed
    // remove the NEW one by unitId, no-op'ing the next show(). The entry is
    // cleared on close/failure, after which a fresh load is allowed.
    if (interstitials.containsKey(unitId)) {
      promise.reject(
        "buzzvil_interstitial_load_failed",
        "An interstitial for this unitId is already loaded or loading; wait for onInterstitialClosed before loading again.",
      )
      return
    }
    // type sentinel: "bottomSheet" → bottom sheet; "dialog"/""/unknown → dialog.
    val builder = BuzzInterstitial.Builder(unitId)
    val interstitial =
      if (type == "bottomSheet") builder.buildBottomSheet() else builder.buildDialog()
    if (interstitial == null) {
      promise.reject(
        "buzzvil_interstitial_load_failed",
        "Failed to build a BuzzInterstitial for unitId=$unitId.",
      )
      return
    }
    // Store from load-start; the guard above keys off its presence, and it's
    // removed on close/failure.
    interstitials[unitId] = interstitial

    // The SDK listener can fire repeatedly; settle the promise exactly once.
    var settled = false
    interstitial.load(
      object : BuzzInterstitialListener() {
        override fun onAdLoaded() {
          if (settled) return
          settled = true
          // Keep the instance in `interstitials` for the later show().
          promise.resolve(null)
        }

        override fun onAdLoadFailed(error: BuzzAdError?) {
          if (settled) return
          settled = true
          interstitials.remove(unitId)
          promise.reject(
            "buzzvil_interstitial_load_failed",
            error?.message ?: error?.type?.toString() ?: "Interstitial load failed.",
          )
        }

        override fun onAdClosed() {
          // New-Arch typed EventEmitter: codegen generates this concrete emit
          // method on the spec base; payload is a flat primitive map.
          emitOnInterstitialClosed(Arguments.createMap().apply { putString("unitId", unitId) })
          // Lifecycle: drop the dismissed instance so the map doesn't retain it
          // (and so a fresh loadInterstitial for this unitId is allowed again).
          interstitials.remove(unitId)
        }
      },
    )
  }

  override fun showInterstitial(unitId: String) {
    // show() presents UI — must run on the main thread (parity with BenefitHub).
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity ?: return@runOnUiThread
      interstitials[unitId]?.show(activity)
    }
  }

  companion object {
    const val NAME = NativeBuzzvilSpec.NAME
  }
}
