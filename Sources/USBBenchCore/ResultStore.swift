import Foundation
import SQLite3

public enum ResultStoreError: LocalizedError {
  case cannotOpenDatabase(String)
  case databaseFailure(String)
  case invalidSavedData

  public var errorDescription: String? {
    switch self {
    case .cannotOpenDatabase(let message):
      "Could not open the database: \(message)"
    case .databaseFailure(let message):
      "Database error: \(message)"
    case .invalidSavedData:
      "A saved result is no longer readable."
    }
  }
}

public final class ResultStore: @unchecked Sendable {
  private var database: OpaquePointer?
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let lock = NSLock()

  public static var defaultDatabaseURL: URL {
    let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    return
      applicationSupport
      .appendingPathComponent("USB Bench", isDirectory: true)
      .appendingPathComponent("results.sqlite3", isDirectory: false)
  }

  public init(databaseURL: URL = ResultStore.defaultDatabaseURL) throws {
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    decoder.dateDecodingStrategy = .millisecondsSince1970

    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let result = sqlite3_open_v2(
      databaseURL.path,
      &database,
      SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
      nil
    )
    guard result == SQLITE_OK else {
      let message =
        database.flatMap { String(cString: sqlite3_errmsg($0)) }
        ?? "errore sconosciuto"
      sqlite3_close(database)
      database = nil
      throw ResultStoreError.cannotOpenDatabase(message)
    }

    try execute(
      """
      CREATE TABLE IF NOT EXISTS results (
          id TEXT PRIMARY KEY NOT NULL,
          created_at REAL NOT NULL,
          subject_kind TEXT NOT NULL,
          subject_name TEXT NOT NULL,
          volume_id TEXT,
          reference_result_id TEXT,
          trashed_at REAL,
          payload BLOB NOT NULL
      );
      """)
    if try !hasColumn("trashed_at", in: "results") {
      try execute("ALTER TABLE results ADD COLUMN trashed_at REAL;")
    }
    try execute(
      """
      CREATE INDEX IF NOT EXISTS results_created_at
      ON results(created_at DESC);
      """)
    try execute(
      """
      CREATE INDEX IF NOT EXISTS results_subject
      ON results(subject_kind, volume_id);
      """)
    try execute(
      """
      CREATE INDEX IF NOT EXISTS results_trashed
      ON results(trashed_at, created_at DESC);
      """)
  }

  deinit {
    sqlite3_close(database)
  }

  public func save(_ result: SavedBenchmark) throws {
    lock.lock()
    defer { lock.unlock() }

    let data = try encoder.encode(result)
    let sql = """
      INSERT OR REPLACE INTO results
      (id, created_at, subject_kind, subject_name, volume_id, reference_result_id, payload)
      VALUES (?, ?, ?, ?, ?, ?, ?);
      """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      throw failure()
    }
    defer { sqlite3_finalize(statement) }

    bindText(result.id.uuidString, to: statement, index: 1)
    sqlite3_bind_double(statement, 2, result.createdAt.timeIntervalSince1970)
    bindText(result.subjectKind.rawValue, to: statement, index: 3)
    bindText(result.subjectName, to: statement, index: 4)
    bindOptionalText(result.volume.stableIdentifier, to: statement, index: 5)
    bindOptionalText(result.referenceResultID?.uuidString, to: statement, index: 6)
    _ = data.withUnsafeBytes { rawBuffer in
      sqlite3_bind_blob(
        statement,
        7,
        rawBuffer.baseAddress,
        Int32(rawBuffer.count),
        sqliteTransient
      )
    }

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw failure()
    }
  }

  public func loadAll() throws -> [SavedBenchmark] {
    try load(whereClause: "trashed_at IS NULL", orderColumn: "created_at")
  }

  public func loadTrashed() throws -> [SavedBenchmark] {
    try load(whereClause: "trashed_at IS NOT NULL", orderColumn: "trashed_at")
  }

  public func trash(id: UUID) throws {
    try updateTrashDate(id: id, date: Date())
  }

  public func restore(id: UUID) throws {
    try updateTrashDate(id: id, date: nil)
  }

  public func deletePermanently(id: UUID) throws {
    lock.lock()
    defer { lock.unlock() }

    let sql = "DELETE FROM results WHERE id = ?;"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      throw failure()
    }
    defer { sqlite3_finalize(statement) }
    bindText(id.uuidString, to: statement, index: 1)
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw failure()
    }
  }

  @available(*, deprecated, message: "Use trash(id:) or deletePermanently(id:)")
  public func delete(id: UUID) throws {
    try deletePermanently(id: id)
  }

  private func load(
    whereClause: String,
    orderColumn: String
  ) throws -> [SavedBenchmark] {
    lock.lock()
    defer { lock.unlock() }

    let sql = """
      SELECT payload FROM results
      WHERE \(whereClause)
      ORDER BY \(orderColumn) DESC;
      """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      throw failure()
    }
    defer { sqlite3_finalize(statement) }

    var results: [SavedBenchmark] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      guard let bytes = sqlite3_column_blob(statement, 0) else {
        throw ResultStoreError.invalidSavedData
      }
      let count = Int(sqlite3_column_bytes(statement, 0))
      let data = Data(bytes: bytes, count: count)
      guard let result = try? decoder.decode(SavedBenchmark.self, from: data) else {
        throw ResultStoreError.invalidSavedData
      }
      results.append(result)
    }
    return results
  }

  private func updateTrashDate(id: UUID, date: Date?) throws {
    lock.lock()
    defer { lock.unlock() }

    let sql = "UPDATE results SET trashed_at = ? WHERE id = ?;"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      throw failure()
    }
    defer { sqlite3_finalize(statement) }
    if let date {
      sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
    } else {
      sqlite3_bind_null(statement, 1)
    }
    bindText(id.uuidString, to: statement, index: 2)
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw failure()
    }
  }

  private func hasColumn(_ column: String, in table: String) throws -> Bool {
    let sql = "PRAGMA table_info(\(table));"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      throw failure()
    }
    defer { sqlite3_finalize(statement) }
    while sqlite3_step(statement) == SQLITE_ROW {
      guard let pointer = sqlite3_column_text(statement, 1) else { continue }
      if String(cString: pointer) == column {
        return true
      }
    }
    return false
  }

  private func execute(_ sql: String) throws {
    var errorPointer: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &errorPointer) == SQLITE_OK else {
      let message = errorPointer.map { String(cString: $0) } ?? "errore sconosciuto"
      sqlite3_free(errorPointer)
      throw ResultStoreError.databaseFailure(message)
    }
  }

  private func failure() -> ResultStoreError {
    let message =
      database.flatMap { String(cString: sqlite3_errmsg($0)) }
      ?? "errore sconosciuto"
    return .databaseFailure(message)
  }

  private func bindText(
    _ value: String,
    to statement: OpaquePointer?,
    index: Int32
  ) {
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
  }

  private func bindOptionalText(
    _ value: String?,
    to statement: OpaquePointer?,
    index: Int32
  ) {
    if let value {
      bindText(value, to: statement, index: index)
    } else {
      sqlite3_bind_null(statement, index)
    }
  }

  private var sqliteTransient: sqlite3_destructor_type {
    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
  }
}
