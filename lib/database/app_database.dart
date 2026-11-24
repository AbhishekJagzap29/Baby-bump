import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/bump_entry.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  // In-memory fallback if platform doesn't have sqflite C bindings (e.g. desktop/web during preview)
  final List<BumpEntry> _memoryStore = [];
  int _memoryIdCounter = 1;
  bool _useMemoryFallback = false;

  AppDatabase._init();

  Future<Database?> get database async {
    if (_useMemoryFallback) return null;
    if (_database != null) return _database!;

    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        // Desktop or Web without special sqlite ffi setup -> fallback to memory store seamlessly
        _useMemoryFallback = true;
        _populateSeedData();
        return null;
      }
      _database = await _initDB('baby_bump_counter.db');
      return _database!;
    } catch (e) {
      _useMemoryFallback = true;
      _populateSeedData();
      return null;
    }
  }

  void _populateSeedData() {
    if (_memoryStore.isNotEmpty) return;
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    _memoryStore.addAll([
      BumpEntry(
        id: _memoryIdCounter++,
        date: today,
        time: '09:15',
        location: 'Upper Left',
        count: 4,
        note: 'Gentle flutter kicks after warm milk',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      BumpEntry(
        id: _memoryIdCounter++,
        date: today,
        time: '13:40',
        location: 'Center / Navel Area',
        count: 6,
        note: 'Active rolls after lunchtime',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      ),
      BumpEntry(
        id: _memoryIdCounter++,
        date: yesterdayStr,
        time: '11:20',
        location: 'Lower Center',
        count: 5,
        note: 'Morning stretch kicks',
        createdAt: yesterday.toIso8601String(),
      ),
      BumpEntry(
        id: _memoryIdCounter++,
        date: yesterdayStr,
        time: '20:45',
        location: 'Middle Right',
        count: 7,
        note: 'Strong bedtime movement',
        createdAt: yesterday.add(const Duration(hours: 9)).toIso8601String(),
      ),
    ]);
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bump_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        location TEXT NOT NULL,
        bump_count INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertBump(BumpEntry entry) async {
    final db = await database;
    if (db == null) {
      final newId = _memoryIdCounter++;
      final savedEntry = entry.copyWith(id: newId);
      _memoryStore.insert(0, savedEntry);
      return newId;
    }
    return await db.insert('bump_entries', entry.toMap());
  }

  Future<List<BumpEntry>> getAllEntries() async {
    final db = await database;
    if (db == null) {
      final list = List<BumpEntry>.from(_memoryStore);
      list.sort((a, b) {
        final dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;
        return b.time.compareTo(a.time);
      });
      return list;
    }

    final result = await db.query(
      'bump_entries',
      orderBy: 'date DESC, time DESC',
    );
    return result.map((json) => BumpEntry.fromMap(json)).toList();
  }

  Future<List<BumpEntry>> getEntriesByDate(String date) async {
    final db = await database;
    if (db == null) {
      return _memoryStore
          .where((e) => e.date == date)
          .toList()
        ..sort((a, b) => b.time.compareTo(a.time));
    }

    final result = await db.query(
      'bump_entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'time DESC',
    );
    return result.map((json) => BumpEntry.fromMap(json)).toList();
  }

  Future close() async {
    final db = await database;
    if (db != null) {
      await db.close();
    }
  }
}
