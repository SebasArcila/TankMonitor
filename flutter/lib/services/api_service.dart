import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';

class ApiService {
  // Nota: Para emuladores Android, usar 'http://10.0.2.2:8080' en lugar de localhost.
  static const String baseUrl = 'http://localhost:8080';

  Future<SensorData> getLatestStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/status'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
      return SensorData.fromJson(json);
    } else if (response.statusCode == 404) {
      throw Exception('Todavía no hay lecturas registradas en el backend');
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  Future<List<SensorData>> getHistory({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/history?limit=$limit'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonList
          .map((item) => SensorData.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }
}
