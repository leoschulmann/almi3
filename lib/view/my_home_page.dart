import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../model/db/db.dart';
import '../model/dto/root_dto.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  final AppDatabase database;

  const MyHomePage({super.key, required this.title, required this.database});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> _fetchFromApi() async {
    try {
      final Dio dio = Dio();
      final Response<dynamic> response = await dio.get(
        'http://localhost:9999/api/root?page=0&size=1000',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody =
            response.data as Map<String, dynamic>;
        final List<dynamic> data = responseBody['content'] is List
            ? responseBody['content'] as List<dynamic>
            : [];

        for (final item in data) {
          final RootDto rootDto = RootDto.fromJson(
            item as Map<String, dynamic>,
          );

          await widget.database
              .into(widget.database.rootTable)
              .insert(
                RootTableCompanion(
                  id: drift.Value(rootDto.id),
                  value: drift.Value(rootDto.value),
                  version: drift.Value(rootDto.version),
                ),
              );

          print('inserted ${rootDto.id} ${rootDto.value} ${rootDto.version}');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully inserted ${data.length} items')),
        );
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('API Error: ${e.message}')));
      print(e);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));

      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            ElevatedButton(
              onPressed: _fetchFromApi,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 32,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_download, size: 48),
                  const SizedBox(height: 8),
                  const Text('Fetch from API'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
