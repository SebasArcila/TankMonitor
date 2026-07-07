import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/sensor_data.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  SensorData? _status;
  List<SensorData> _history = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _apiService.getLatestStatus();
      final history = await _apiService.getHistory(limit: 20);

      if (!mounted) return;

      setState(() {
        _status = status;
        _history = history;
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    try {
      final status = await _apiService.getLatestStatus();
      final history = await _apiService.getHistory(limit: 20);

      if (!mounted) return;

      setState(() {
        _status = status;
        _history = history;
        _errorMessage = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Sin conexión con el backend';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TankMonitor'),
        actions: [_buildLiveIndicator()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'Historial de temperatura',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTemperatureChart(),
                  const SizedBox(height: 24),
                  const Text(
                    'Últimas lecturas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildHistoryList(),
                ],
              ),
            ),
    );
  }

  Widget _buildLiveIndicator() {
    final isLive = _errorMessage == null && _status != null;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isLive ? Colors.greenAccent : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLive ? 'En vivo' : 'Sin conexión',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_errorMessage — mostrando el último dato conocido',
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final data = _status;
    if (data == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin lecturas todavía.'),
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estado actual',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Icon(
                  data.pump ? Icons.water_drop : Icons.water_drop_outlined,
                  color: data.pump ? Colors.blue : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricRow('Temperatura', '${data.temperature.toStringAsFixed(1)} °C'),
            _buildMetricRow('pH', data.ph.toStringAsFixed(2)),
            _buildMetricRow('Nivel', '${data.level.toStringAsFixed(1)} %'),
            _buildMetricRow('Bomba', data.pump ? 'Encendida' : 'Apagada'),
            if (_lastUpdated != null) ...[
              const Divider(height: 20),
              Text(
                'Última actualización: ${_lastUpdated!.toLocal().toString().substring(11, 19)}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart() {
    if (_history.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Sin datos suficientes para graficar')),
      );
    }

    final reversed = _history.reversed.toList();
    final spots = <FlSpot>[
      for (int i = 0; i < reversed.length; i++)
        FlSpot(i.toDouble(), reversed[i].temperature),
    ];

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Text('Sin lecturas todavía.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              item.pump ? Icons.water_drop : Icons.water_drop_outlined,
              color: item.pump ? Colors.blue : Colors.grey,
            ),
            title: Text(
              'Temp: ${item.temperature.toStringAsFixed(1)}°C   pH: ${item.ph.toStringAsFixed(2)}',
            ),
            subtitle: Text(
              'Nivel: ${item.level.toStringAsFixed(1)}%   ${item.createdAt.toLocal()}',
            ),
          ),
        );
      },
    );
  }
}
