# StockScope — Stock Comparison Analyzer

**Compare. Analyze. Understand.**

A Flutter (Material 3, Riverpod) app for comparing 2–5 stocks using historical
prices: normalized performance, returns, historical volatility, highest/lowest
closes and dividend information. It runs fully offline in a clearly labelled
**demo mode** and can use a real market-data provider (Twelve Data) with your
own API key.

> Educational use only. Not investment advice. No trading, no brokerage
> connection. See [Financial disclaimer](#20-financial-disclaimer).

## 1. Project overview
StockScope lets a user search stocks, build a comparison set, pick a date range,
and view charts and metrics side by side, plus per-stock details, a persistent
watchlist, and light/dark themes.

## 2. Problem statement
Comparing stocks with different price levels, currencies and trading calendars
is error-prone. Raw price charts are not comparable, and risk is rarely shown
next to return. StockScope normalizes series to a common base and shows return
and volatility together, with the assumptions stated.

## 3. Objectives
* Compare 2–5 stocks over a chosen period on a common, date-aligned basis.
* Calculate returns and historical volatility with tested formulas.
* Be honest about data: label demo, cached and missing data; never fabricate.
* Work without an API key (demo) and degrade gracefully when the network fails.

## 4. Key features
Splash, home dashboard, debounced search, comparison setup (presets + custom
range, validation), comparison results (normalized / % return / price chart,
summary cards, metrics, volatility, dividends), stock details with price chart,
watchlist (persisted, multi-select compare), settings (theme, default period,
preferred market, data source), loading/empty/error states with retry.

## 5. Technology stack
Flutter, Dart (>=3.4), Material 3, `flutter_riverpod` 2.x, `fl_chart` 0.69,
`dio`, `shared_preferences`, `flutter_dotenv`, `intl`. Tests: `flutter_test`.

## 6. Architecture
Feature-oriented, three layers:
* **Presentation** — `lib/features/*`, `lib/widgets/*`
* **Domain/logic** — `lib/services/*` (pure calculations, comparison builder),
  `lib/providers/*` (Riverpod state), `lib/models/*`
* **Data** — `lib/data/datasources/*` (`MarketDataSource` interface, demo and
  Twelve Data implementations), `lib/data/repositories/stock_repository.dart`
  (validation, cache, request de-duplication)

## 7. Folder structure
```
lib/
  main.dart, app.dart
  core/        constants, errors, network (Dio client), theme, utils
  models/      stock, historical_price, price_series, dividend_info, stock_comparison
  data/        datasources/{market_data_source, demo_..., remote_...}, repositories/
  services/    stock_calculation_service, comparison_builder
  providers/   settings_provider, watchlist_provider, stock_providers
  widgets/     reusable UI (cards, charts, states, badges)
  features/    splash, shell, dashboard, stock_search, comparison,
               stock_details, watchlist, settings
test/          services, data, models, widgets
scripts/       setup_android.sh
```
`android/` is **not** included; generate it with the script below.

## 8. Prerequisites
Flutter stable SDK (3.22 or newer, i.e. Dart 3.4+), Android Studio or VS Code,
an Android emulator or device. Check with `flutter doctor`.

## 9. Installation
```
cd stock_scope
sh scripts/setup_android.sh      # creates android/, adds INTERNET permission, runs pub get
```
Or manually:
```
flutter create --platforms=android --project-name stock_scope --org com.example.stockscope .
rm -f test/widget_test.dart      # if the template generated one
flutter pub get
```
and add `<uses-permission android:name="android.permission.INTERNET"/>` inside
`<manifest>` of `android/app/src/main/AndroidManifest.xml` (release builds need
it to reach the network).

## 10. Run in demo mode (no API key)
```
flutter run
```
With no key configured the app starts in demo mode. A **DEMO DATA** badge is
shown wherever synthetic data appears. Demo symbols: RELIANCE, TCS, INFY,
HDFCBANK, ITC (synthetic, reproducible, history since Jan 2015; ITC and TCS have
deliberately missing days; RELIANCE has no dividend data to demonstrate
"unavailable").

## 11. Enable remote market data
1. Create a Twelve Data account and copy your API key.
2. Edit `.env` (a copy of `.env.example`; git-ignored):
   `TWELVE_DATA_API_KEY=your_key`
3. Restart the app, then Settings → Data source → **Live provider**.

If the provider fails the app shows an error with retry and an optional
"Use demo data" button. It never silently substitutes synthetic data.

**Security:** values in a Flutter `.env` asset are bundled into the app and can
be extracted from the APK. That is acceptable for a personal key in a lab
project only. For production, keep the key on a backend that proxies requests.

## 12. Tests and analysis
```
flutter pub get
dart format .
flutter analyze
flutter test
```
Tests use no network and no API key.

## 13. Build an Android APK
```
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`.
(The default template signs release builds with the debug key — fine for demos.)

## 14. Known limitations
* **Not compiled or run when generated.** The environment that produced this
  source had no Flutter SDK and no network. Run `flutter analyze` and
  `flutter test` and fix any findings before presenting; small API drift
  between package versions is possible.
* **Twelve Data integration is unverified against the live API.** It follows
  the public docs (endpoints, parameters, response shape and error format as
  described in `remote_market_data_source.dart`) but was not exercised with a
  real key. The `SYMBOL:EXCHANGE` handling (e.g. `RELIANCE:NSE`) and the
  `adjust=splits` parameter in particular should be checked.
* Provider plans limit history depth, markets (NSE/BSE often need a paid plan),
  dividends and requests per minute (free tier is small; comparing 5 stocks
  uses 5 requests, and dividends add more).
* Prices are **split-adjusted, not dividend-adjusted** from the remote provider
  (returns exclude dividends). Demo prices are unadjusted.
* Dividend yield and annual dividend totals are intentionally not calculated.
* Metrics table shows dividends on their own tab, not as a table row.
* Different calendars: lines start at the first date shared by all stocks.
* Demo data uses a fixed weekday calendar with no exchange holidays.
* Only Android was targeted; no platform-specific code is used elsewhere, but
  other platforms were not set up or tested.
* Screens 6–9 (metrics, history, volatility, dividends) are implemented as
  tabs of the comparison screen and sections of the stock details screen.

## 15. Data-source attribution
Live data: [Twelve Data](https://twelvedata.com) (subject to its terms and
your plan). Demo data: synthetic, generated in-app, not real prices.

## 16. Formulas
Return `(end-start)/start*100`; normalized `P/P0*100`; daily return
`P(t)/P(t-1)-1`; volatility = sample std-dev of daily returns × √252;
average daily return = arithmetic mean (not compound).

## 20. Financial disclaimer
StockScope is an educational tool. Information shown is historical, may be
delayed, incomplete or synthetic (in demo mode) and is not investment advice.
Past performance does not predict future results. StockScope cannot place
trades and is not affiliated with any broker, exchange or financial institution.
