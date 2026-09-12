import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/seed_ids.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Generates a new UUID string for text primary keys.
String _newUuid() => const Uuid().v4();

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Bookkeeping transactions. Amounts are stored as integer cents only.
class Transactions extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text().clientDefault(_newUuid)();

  /// Amount stored as integer cents. Never store money as floating point.
  IntColumn get amountCents => integer()();

  /// expense / income / transfer (placeholder).
  TextColumn get type => textEnum<TransactionType>()();

  /// Nullable: category can be backfilled later (record-first philosophy).
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();

  DateTimeColumn get occurredAt => dateTime()();

  /// True while the record is a quick-capture draft (record-first workflow).
  BoolColumn get isDraft => boolean().withDefault(const Constant(false))();

  /// manual (M1.0) / screenshot / voice (reserved).
  TextColumn get source =>
      textEnum<TransactionSource>().clientDefault(() => TransactionSource.manual.name)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Tombstone timestamp; null means the row is alive. Never physically delete.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transaction categories. Nine fixed seeds are inserted on database creation;
/// users may add custom categories later.
class Categories extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text().clientDefault(_newUuid)();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get sort => integer()();

  /// False for the nine built-in seeds, true for user-defined categories.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Asset records. Value and sale price are stored as integer cents.
class Assets extends Table {
  @override
  String get tableName => 'assets';

  TextColumn get id => text().clientDefault(_newUuid)();
  TextColumn get name => text()();

  /// hardCurrency / digital / nonStandard / ordinary.
  TextColumn get category => textEnum<AssetCategory>()();

  /// Current value in integer cents.
  IntColumn get valueCents => integer()();
  DateTimeColumn get purchasedAt => dateTime()();

  /// Local file path only; photo files use content-hash naming.
  TextColumn get photoPath => text().nullable()();

  /// inService / retired / sold.
  TextColumn get status =>
      textEnum<AssetStatus>().clientDefault(() => AssetStatus.inService.name)();

  IntColumn get soldPriceCents => integer().nullable()();
  DateTimeColumn get soldAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// Asset photos (T-09B): multiple photos per asset, first by sort = cover.
///
/// Tombstone pattern: removals mark [deletedAt], rows are never deleted.
class AssetPhotos extends Table {
  @override
  String get tableName => 'asset_photos';

  TextColumn get id => text().clientDefault(_newUuid)();

  /// Owning asset (FK to assets.id).
  TextColumn get assetId => text().references(Assets, #id)();

  /// Absolute file path; files are content-hash named by PhotoService.
  TextColumn get path => text()();

  /// Display order; the lowest sort is the cover (main) photo.
  IntColumn get sort => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Monthly budgets (T-10). One row per calendar month, keyed by `YYYY-MM`.
///
/// `income_cents` and `savings_target_cents` are integer cents only; the
/// spendable budget (`income - savings`) is derived, never stored.
class BudgetMonths extends Table {
  @override
  String get tableName => 'budget_months';

  TextColumn get id => text().clientDefault(_newUuid)();

  /// Calendar month key in `YYYY-MM` form (e.g. `2026-09`). Unique.
  TextColumn get yearMonth => text()();

  /// Total income entered by the user for the month, in integer cents.
  IntColumn get incomeCents => integer()();

  /// Planned savings for the month, in integer cents.
  IntColumn get savingsTargetCents => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Tombstone timestamp; null means the row is alive. Never physically delete.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {yearMonth},
      ];
}

@DriftDatabase(tables: [Transactions, Categories, Assets, AssetPhotos, BudgetMonths])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // V1 -> V2: introduce asset_photos. Legacy single-photo assets
            // migrate their photoPath into the new table as sort 0 (cover).
            await m.createTable(assetPhotos);
            final legacy = await select(assets).get();
            final rows = <AssetPhotosCompanion>[];
            for (final asset in legacy) {
              final path = asset.photoPath;
              if (path == null || path.isEmpty) continue;
              rows.add(
                AssetPhotosCompanion.insert(
                  assetId: asset.id,
                  path: path,
                  sort: 0,
                ),
              );
            }
            if (rows.isNotEmpty) {
              await batch((b) => b.insertAll(assetPhotos, rows));
            }
          }
          if (from < 3) {
            // V2 -> V3: introduce budget_months. No backfill: months without a
            // budget are a normal state (home shows the onboarding card).
            await m.createTable(budgetMonths);
          }
        },
      );

  /// Inserts the nine fixed categories (v1 seed).
  Future<void> _seedCategories() async {
    final now = DateTime.now().toUtc();
    final seeds = <CategoriesCompanion>[
      _seedRow(categoryIdDining, '餐饮', 'restaurant', 0, now),
      _seedRow(categoryIdTransport, '交通', 'commute', 1, now),
      _seedRow(categoryIdShopping, '购物', 'shopping_bag', 2, now),
      _seedRow(categoryIdHousing, '居住', 'home', 3, now),
      _seedRow(categoryIdEntertainment, '娱乐', 'sports_esports', 4, now),
      _seedRow(categoryIdStudy, '学习', 'school', 5, now),
      _seedRow(categoryIdMedical, '医疗', 'medical_services', 6, now),
      _seedRow(categoryIdGift, '人情', 'redeem', 7, now),
      _seedRow(categoryIdOther, '其他', 'category', 8, now),
    ];
    await batch((b) {
      b.insertAll(categories, seeds, mode: InsertMode.insertOrIgnore);
    });
  }

  CategoriesCompanion _seedRow(
    String id,
    String name,
    String icon,
    int sort,
    DateTime now,
  ) =>
      CategoriesCompanion.insert(
        id: Value(id),
        name: name,
        icon: Value(icon),
        sort: sort,
        isCustom: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  /// All non-deleted transactions, newest first.
  Selectable<Transaction> get liveTransactions =>
      (select(transactions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(u) => OrderingTerm.desc(u.occurredAt)]));

  /// All non-deleted categories ordered by the fixed sort field.
  Selectable<Category> get liveCategories =>
      (select(categories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(u) => OrderingTerm.asc(u.sort)]));

  /// All non-deleted assets, newest purchase first.
  Selectable<Asset> get liveAssets =>
      (select(assets)
            ..where((a) => a.deletedAt.isNull())
            ..orderBy([(u) => OrderingTerm.desc(u.purchasedAt)]));
}

// ---------------------------------------------------------------------------
// Platform connection
// ---------------------------------------------------------------------------

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'gringotts.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Opens the production database connection for the current platform.
AppDatabase openConnection() => AppDatabase(_openConnection());
