# react-native-buzzvil-ad

> [!IMPORTANT]
> **This is an unofficial, community-maintained package — NOT an official Buzzvil product.**
> It is not affiliated with, endorsed by, or supported by Buzzvil. "Buzzvil" and "BuzzBenefit"
> are trademarks of their respective owners. Use at your own risk: neither the maintainer nor
> Buzzvil is responsible for any issues arising from its use.

An unofficial React Native wrapper for the Buzzvil **BuzzBenefit v6** SDK (Android & iOS).

## Installation

```sh
npm install react-native-buzzvil-ad
```

## Usage

```js
import {
  initialize,
  login,
  logout,
  isLoggedIn,
  showBenefitHub,
} from 'react-native-buzzvil-ad';

// Call once at app startup, before any other method:
initialize('YOUR_BUZZVIL_APP_ID');

// Log a user in (gender / birthYear are optional):
await login({ userId: 'user-123', gender: 'MALE', birthYear: 1990 });

// Present the BenefitHub (offerwall):
showBenefitHub();

// Session helpers:
const loggedIn = await isLoggedIn();
logout();
```

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## Disclaimer

This is an unofficial, community-maintained project and is **not** affiliated with, endorsed by, or sponsored by Buzzvil. All product names, logos, and brands — including "Buzzvil" and "BuzzBenefit" — are the property of their respective owners. This package is provided "as is", without warranty of any kind; the maintainer and Buzzvil accept no liability for any damages or issues arising from its use. For official SDKs and support, refer to [Buzzvil's official documentation](https://docs.buzzvil.com).

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
