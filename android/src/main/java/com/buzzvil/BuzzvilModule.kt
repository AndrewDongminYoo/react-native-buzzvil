package com.buzzvil

import android.app.Application
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil

// The Buzzvil class names and import paths below are verified against the
// resolved `com.buzzvil:buzzvil-sdk` AAR (buzzvil-bom 6.7.x) — this module
// compiles cleanly via `:dongminyu_react-native-buzzvil:compileDebugKotlin`.
import com.buzzvil.buzzbenefit.BuzzBenefitConfig
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHub
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHubConfig
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHubPage
import com.buzzvil.sdk.BuzzvilSdk
import com.buzzvil.sdk.BuzzvilSdkLoginListener
import com.buzzvil.sdk.BuzzvilSdkUser

class BuzzvilModule(reactContext: ReactApplicationContext) :
  NativeBuzzvilSpec(reactContext) {

  override fun initialize(appId: String) {
    val application = reactApplicationContext.applicationContext as Application
    val config = BuzzBenefitConfig.Builder(appId).build()
    BuzzvilSdk.initialize(application, config)
  }

  override fun login(userId: String, gender: String, birthYear: Double, promise: Promise) {
    // Sentinel contract (see NativeBuzzvil.ts): "" gender / 0 birthYear → unset.
    val user = BuzzvilSdkUser(
      userId = userId,
      gender = when (gender) {
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

  override fun showBenefitHub(routePath: String, showHistory: Boolean) {
    // BenefitHub launches an Activity — must run on the main thread (parity
    // with the iOS dispatch_async(main) path).
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity ?: return@runOnUiThread
      val configBuilder = BuzzBenefitHubConfig.Builder()
      if (routePath.isNotEmpty()) {
        configBuilder.routePath(routePath)
      }
      if (showHistory) {
        configBuilder.queryParams(BuzzBenefitHubPage.HISTORY.toRedirectQueryParams())
      }
      BuzzBenefitHub.show(activity, configBuilder.build())
    }
  }

  companion object {
    const val NAME = NativeBuzzvilSpec.NAME
  }
}
