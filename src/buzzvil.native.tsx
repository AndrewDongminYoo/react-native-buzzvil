import Buzzvil from './NativeBuzzvil';
import type { BuzzvilUser, BenefitHubOptions } from './types';

/**
 * Native (iOS/Android) implementation of the public Buzzvil API. Maps the
 * friendly types in `./types` onto the primitive-only native spec, applying
 * the sentinel contract documented in `./NativeBuzzvil`.
 */

/** Initialize the BuzzBenefit SDK. Call once, before any other method. */
export function initialize(appId: string): void {
  Buzzvil.initialize(appId);
}

/** Log a user in. Resolves on success, rejects on SDK failure. */
export function login(user: BuzzvilUser): Promise<void> {
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
