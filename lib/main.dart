import 'package:almi3/model/db/db.dart';
import 'package:almi3/view/my_app.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = AppDatabase();
  runApp(MyApp(database: appDatabase));
}
