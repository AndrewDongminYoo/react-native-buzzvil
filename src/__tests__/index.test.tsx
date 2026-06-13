import { jest, beforeEach, describe, it, expect } from '@jest/globals';

// Shared registry of handlers subscribed via the generated `onInterstitialClosed`
// EventEmitter member, so tests can drive the close event and assert
// unsubscription. Declared with the `mock` prefix so jest's module-factory
// hoisting allows the out-of-scope reference.
const mockClosedHandlers = new Set<(e: { unitId: string }) => void>();

// Self-contained factory (no out-of-scope refs → no hoisting TDZ trap). The
// codegen native module is mocked so the wrapper runs without a native runtime.
// `onInterstitialClosed` mirrors the codegen EventEmitter shape:
// `(handler) => EventSubscription` (`{ remove() }`).
jest.mock('../NativeBuzzvil', () => ({
  __esModule: true,
  default: {
    initialize: jest.fn(),
    login: jest.fn(() => Promise.resolve()),
    logout: jest.fn(),
    isLoggedIn: jest.fn(() => Promise.resolve(true)),
    showBenefitHub: jest.fn(),
    loadInterstitial: jest.fn(() => Promise.resolve()),
    showInterstitial: jest.fn(),
    onInterstitialClosed: jest.fn(
      (handler: (e: { unitId: string }) => void) => {
        mockClosedHandlers.add(handler);
        return {
          remove: () => {
            mockClosedHandlers.delete(handler);
          },
        };
      }
    ),
  },
}));

import Buzzvil from '../NativeBuzzvil';
import {
  initialize,
  login,
  logout,
  isLoggedIn,
  showBenefitHub,
  userIdWarnings,
} from '../buzzvil.native';
import {
  loadInterstitial,
  showInterstitial,
  addInterstitialClosedListener,
} from '../interstitial.native';

/** Drive every subscribed close handler, as the native emitter would. */
function emitInterstitialClosed(unitId: string): void {
  for (const handler of mockClosedHandlers) {
    handler({ unitId });
  }
}

// `jest.mocked` preserves the Spec signatures, so `toHaveBeenCalledWith` is
// arity-checked against the real native method shapes.
const native = jest.mocked(Buzzvil);

beforeEach(() => {
  jest.clearAllMocks();
  mockClosedHandlers.clear();
});

describe('buzzvil native wrapper — sentinel mapping', () => {
  it('forwards initialize/logout/isLoggedIn verbatim', async () => {
    initialize('app-id');
    logout();
    expect(native.initialize).toHaveBeenCalledWith('app-id');
    expect(native.logout).toHaveBeenCalledTimes(1);
    await expect(isLoggedIn()).resolves.toBe(true);
  });

  it('encodes omitted gender/birthYear as sentinels', () => {
    login({ userId: 'u1' });
    expect(native.login).toHaveBeenCalledWith('u1', '', 0);
  });

  it('passes through provided gender/birthYear', () => {
    login({ userId: 'u2', gender: 'MALE', birthYear: 1990 });
    expect(native.login).toHaveBeenCalledWith('u2', 'MALE', 1990);
  });

  it('defaults BenefitHub options to sentinels', () => {
    showBenefitHub();
    expect(native.showBenefitHub).toHaveBeenCalledWith('', false);
  });

  it('maps showHistory and routePath', () => {
    showBenefitHub({ routePath: '0', showHistory: true });
    expect(native.showBenefitHub).toHaveBeenCalledWith('0', true);
  });
});

describe('userIdWarnings — dev userId sanity checks', () => {
  it('returns no warnings for a clean non-PII id', () => {
    expect(userIdWarnings('user-1234-abcd')).toEqual([]);
  });

  it('flags an empty userId', () => {
    expect(userIdWarnings('')).toEqual(['userId is empty.']);
  });

  it('flags an email-like userId', () => {
    expect(
      userIdWarnings('ydm2790@naver.com').some((m) => m.includes('email'))
    ).toBe(true);
  });

  it('flags a non-ASCII userId', () => {
    expect(userIdWarnings('유저1').some((m) => m.includes('ASCII'))).toBe(true);
  });

  it('flags a userId over 255 characters', () => {
    expect(userIdWarnings('a'.repeat(256)).some((m) => m.includes('255'))).toBe(
      true
    );
  });
});

describe('interstitial wrapper — argument mapping', () => {
  it('defaults type to "dialog" when omitted', async () => {
    await loadInterstitial('unit-1');
    expect(native.loadInterstitial).toHaveBeenCalledWith('unit-1', 'dialog');
  });

  it('passes through an explicit type', async () => {
    await loadInterstitial('unit-2', 'bottomSheet');
    expect(native.loadInterstitial).toHaveBeenCalledWith(
      'unit-2',
      'bottomSheet'
    );
  });

  it('forwards showInterstitial unitId verbatim', () => {
    showInterstitial('unit-3');
    expect(native.showInterstitial).toHaveBeenCalledWith('unit-3');
  });
});

describe('interstitial wrapper — closed listener', () => {
  it('fires cb only for the matching unitId', () => {
    const cb = jest.fn();
    addInterstitialClosedListener('unit-A', cb);

    emitInterstitialClosed('unit-B'); // different unit → ignored
    expect(cb).not.toHaveBeenCalled();

    emitInterstitialClosed('unit-A'); // matching unit → fires
    expect(cb).toHaveBeenCalledTimes(1);
  });

  it('routes concurrent listeners independently by unitId', () => {
    const cbA = jest.fn();
    const cbB = jest.fn();
    addInterstitialClosedListener('unit-A', cbA);
    addInterstitialClosedListener('unit-B', cbB);

    emitInterstitialClosed('unit-A');
    expect(cbA).toHaveBeenCalledTimes(1);
    expect(cbB).not.toHaveBeenCalled();
  });

  it('remove() unsubscribes so cb no longer fires', () => {
    const cb = jest.fn();
    const sub = addInterstitialClosedListener('unit-A', cb);

    sub.remove();
    emitInterstitialClosed('unit-A');
    expect(cb).not.toHaveBeenCalled();
  });
});
