import 'package:flutter/material.dart';
import 'package:webgis_app/views/map_page.dart';


void main() {
  runApp(const CampusFoodWebGISApp());
}

class CampusFoodWebGISApp extends StatelessWidget {
  const CampusFoodWebGISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebGIS Campus - Onde Comer (BH)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}