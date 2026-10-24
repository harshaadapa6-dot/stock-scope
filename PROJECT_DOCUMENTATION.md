# StockScope — Project Documentation

## Abstract
StockScope is a Flutter application for comparing two to five stocks using
historical daily prices. It normalizes series to a common base, computes
returns and historical volatility, lists highest/lowest closes and dividend
events, and keeps a persistent watchlist. It runs in a synthetic demo mode with
no network, or against Twelve Data with a user-supplied API key. The app is
educational and does not trade or give advice.

## Introduction
Individual investors often compare stocks by eyeballing price charts, which is
misleading when price levels, currencies and trading calendars differ. StockScope
provides date-aligned, normalized comparison with risk shown beside return.

## Problem statement
Raw prices are not comparable across stocks; return without risk is incomplete;
and free data sources are limited and sometimes unavailable. A learning tool
must also be transparent about data quality.

## Objectives
1. Compare 2–5 stocks over selectable periods on a common basis.
2. Calculate return, volatility and related statistics correctly and testably.
3. Remain usable offline through clearly labelled synthetic data.
4. Handle provider errors, rate limits and missing data honestly.

## Scope
In scope: search, comparison, charts, metrics, dividends (where supplied),
watchlist, themes, settings, caching, tests, documentation. Out of scope: trading,
brokerage/bank integration, real-time streaming, forecasting, portfolio
accounting, user accounts, backend services.

## Existing-system limitations
Brokerage and portal charts typically compare a single stock, or overlay raw
prices; they rarely align calendars, state the price basis, or separate missing
from zero dividends, and are tied to a specific broker.

## Proposed system
A mobile client with a pluggable `MarketDataSource`, a pure calculation layer,
Riverpod state, and fl_chart visualisations (see README architecture).

## Functional requirements
* FR1 Search by name/ticker with debounce, empty and error states.
* FR2 Select 2–5 unique stocks; remove; validate date range; presets + custom.
* FR3 Comparison chart in normalized, % return and price modes with tooltips.
* FR4 Summary cards and metric comparison (latest price, change, return,
  volatility, high, low, average daily return).
* FR5 Volatility screen with formula and assumption explanation.
* FR6 Dividend display distinguishing unavailable / none / events.
* FR7 Stock details with price chart and period selector.
* FR8 Watchlist add/remove/persist/multi-select compare.
* FR9 Settings: theme, default period, preferred market, data source, disclaimer.
* FR10 Demo/live switch with persistent DEMO DATA badge.

## Non-functional requirements
Usability on small screens and with text scaling; accessibility (signs and icons
in addition to colour, semantic labels, colour-blind-friendly palette);
reliability (timeouts, one transient retry, no retry on rate limits, no
fabricated data); maintainability (layered, tested calculations); security (no
committed keys, no credentials collected, client-side key caveat); performance
(debounce, cache, in-flight de-duplication).

## Software and hardware requirements
Flutter stable (Dart ≥ 3.4), Android Studio or VS Code, Android SDK; Android
device/emulator with API level supported by the installed Flutter version; a
computer able to run the Android emulator (≈ 8 GB RAM recommended).

## System architecture
Presentation (screens, widgets) → Providers (Riverpod) → Repository (cache,
validation) → `MarketDataSource` (Demo | Twelve Data via `ApiClient`/Dio).
Calculations live in `StockCalculationService` and `ComparisonBuilder`, free of
Flutter and network dependencies.

## Module descriptions
* **core** – constants, `AppException`, Dio client, theme, formatters, date utilities.
* **models** – `Stock`, `HistoricalPrice`, `PriceSeries` (with `PriceBasis`),
  `DividendInfo`/`DividendResult`/`DividendSummary`, `StockComparison`, `StockMetrics`.
* **data** – demo generator (seeded, reproducible), Twelve Data adapter,
  `StockRepository`.
* **services** – calculations and comparison alignment.
* **providers** – settings (persisted), watchlist and recents (persisted),
  selection, range, committed comparison request, comparison, per-stock analysis,
  dividends, quotes.
* **features/widgets** – the screens and reusable components.

## Data flow
User action → provider → repository (cache lookup, in-flight check) → data
source → `PriceSeries` → `ComparisonBuilder` (clean, clip, common start,
normalize, metrics) → `StockComparison` → chart/tables. Changing the period
updates the committed request, which re-triggers the provider.

## Financial formulas
* Absolute change = end − start
* Percentage return = (end − start) / start × 100
* Normalized value = P(t) / P(first) × 100 (first valid observation = 100)
* Daily return r(t) = P(t)/P(t−1) − 1
* Daily volatility = sample standard deviation (n−1) of valid daily returns
* Annualized volatility = daily volatility × √252
* Average daily return = arithmetic mean of daily returns (not geometric)
* Cumulative return = (end/start − 1) × 100
Prices must be finite and > 0; otherwise values are null, never zero. Alignment
uses calendar dates and the latest first-observation date among the stocks, not
array indices.

## Testing strategy
Unit tests: calculations (edge cases: empty, single, zero/negative/NaN/infinite
prices, sorting, de-duplication, dividends), comparison alignment, models and
formatting. Data tests: demo reproducibility and missing data, repository
caching/validation/error propagation, Twelve Data parsing with canned JSON
(success, empty, malformed, 401, 403, 429, offline). Widget tests: splash,
dashboard, debounced search, selection and duplicates, empty/restored watchlist,
comparison loading and error states, theme persistence, settings. No test needs
a network or API key.

## Limitations
Source was written without compiling or running tests (no Flutter SDK or
network available during generation); the live provider adapter is unverified
against the real API; remote prices are split-adjusted only; free plans limit
history, markets and rate; yield/annual dividend totals not calculated; Android
platform folder is generated by a script; demo calendar has no holidays. See
README "Known limitations".

## Future enhancements
Verify and extend the provider adapter (adjusted-close support, more
providers); backend proxy for keys; dividend yield with trailing-12-month
logic; portfolio and correlation views; export (CSV/PDF); notifications;
integration and golden tests; localisation.

## Conclusion
StockScope delivers an honest, testable comparison workflow with explicit
handling of data quality. Before demonstration, run the analyzer and tests on a
machine with Flutter and validate the live provider with a real key.
