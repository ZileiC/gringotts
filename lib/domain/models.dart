/// Domain-level enums shared by the data layer and services.
///
/// All enums are persisted as text values so that adding new members never
/// breaks existing SQLite rows.
library;

/// Direction of a transaction.
///
/// `transfer` is a placeholder reserved for future bookkeeping flows.
/// There is no account system (B3 rejected), so no account field exists.
enum TransactionType { income, expense, transfer }

/// Lifecycle state of an asset.
enum AssetStatus { inService, retired, sold }

/// Asset classification (aligned with the "youshu" reference set).
enum AssetCategory { hardCurrency, digital, nonStandard, ordinary }

/// Where a transaction came from.
///
/// `manual` is the only value used in M1.0; `screenshot` and `voice` are
/// reserved for future milestones.
enum TransactionSource { manual, screenshot, voice }
