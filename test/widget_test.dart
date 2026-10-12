import 'package:flutter_test/flutter_test.dart';
import 'package:in_class_9/main.dart';

void main() {
  test('Database class can be created', () {
    final database = AppDatabase();
    expect(database, isA<AppDatabase>());
  });
}
