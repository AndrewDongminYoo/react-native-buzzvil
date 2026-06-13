import Buzzvil from './NativeBuzzvil';
import type { BuzzvilUser, BenefitHubOptions } from './types';

/**
 * Native (iOS/Android) implementation of the public Buzzvil API. Maps the
 * friendly types in `./types` onto the primitive-only native spec, applying
 * the sentinel contract documented in `./NativeBuzzvil`.
 */

/**
 * Initialize the BuzzBenefit SDK. Call once, before any other method.
 *
 * `appSecret` is the BuzzBanner app secret from the Buzzvil admin; it is only
 * needed when using BuzzBanner (Android). Omit it (sentinel `''`) otherwise.
 */
export function initialize(appId: string, appSecret = ''): void {
  Buzzvil.initialize(appId, appSecret);
}

/**
 * Dev-only sanity checks for `userId`. Buzzvil requires a non-PII, stable,
 * ASCII identifier (≤255 chars) — not an email or login id. Returns a list of
 * human-readable warnings (empty when the id looks fine). Pure: `login` logs
 * these via `console.warn` only under `__DEV__`; it never alters behavior or
 * blocks the call (the SDK is the source of truth on acceptance).
 */
export function userIdWarnings(userId: string): string[] {
  const warnings: string[] = [];
  if (!userId) {
    warnings.push('userId is empty.');
    return warnings;
  }
  if (userId.includes('@')) {
    warnings.push(
      'userId looks like an email — Buzzvil requires a non-PII, stable identifier (not an email/login id); ads may be rejected.'
    );
  }
  if (userId.length > 255) {
    warnings.push('userId exceeds 255 characters.');
  }
  if ([...userId].some((ch) => ch.charCodeAt(0) > 127)) {
    warnings.push('userId should be ASCII.');
  }
  return warnings;
}

/** Log a user in. Resolves on success, rejects on SDK failure. */
export function login(user: BuzzvilUser): Promise<void> {
  if (__DEV__) {
    for (const message of userIdWarnings(user.userId)) {
      console.warn(`[buzzvil] login: ${message}`);
    }
  }
  return Buzzvil.login(user.userId, user.gender ?? '', user.birthYear ?? 0);
}

/** Log the current user out. */
export function logout(): void {
  Buzzvil.logout();
}

/** Whether a user is currently logged in. */
export function isLoggedIn(): Promise<boolean> {
  return Buzzvil.isLoggedIn();
}

/** Present the BenefitHub (offerwall) over the current screen. */
export function showBenefitHub(options: BenefitHubOptions = {}): void {
  Buzzvil.showBenefitHub(options.routePath ?? '', options.showHistory ?? false);
}
