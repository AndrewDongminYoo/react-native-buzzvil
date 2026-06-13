import { jest, beforeEach, describe, it, expect } from '@jest/globals';

// Self-contained factory (no out-of-scope refs → no hoisting TDZ trap). The
// codegen native module is mocked so the wrapper runs without a native runtime.
jest.mock('../NativeBuzzvil', () => ({
  __esModule: true,
  default: {
    initialize: jest.fn(),
    login: jest.fn(() => Promise.resolve()),
    logout: jest.fn(),
    isLoggedIn: jest.fn(() => Promise.resolve(true)),
    showBenefitHub: jest.fn(),
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

// `jest.mocked` preserves the Spec signatures, so `toHaveBeenCalledWith` is
// arity-checked against the real native method shapes.
const native = jest.mocked(Buzzvil);

beforeEach(() => {
  jest.clearAllMocks();
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
