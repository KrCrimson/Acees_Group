import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DebugLogsView extends StatefulWidget {
  @override
  _DebugLogsViewState createState() => _DebugLogsViewState();
}

class _DebugLogsViewState extends State<DebugLogsView> {
  static final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();

  static void addLog(String message, {LogLevel level = LogLevel.info}) {
    _logs.add(LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    ));
    // Mantener solo los últimos 500 logs
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
  }

  static void clearLogs() {
    _logs.clear();
  }

  @override
  void initState() {
    super.initState();
    // Auto-scroll al final cuando se añaden logs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Color(0xFF2D2D2D),
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'LOGS DE DEBUGGING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  clearLogs();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('LIMPIAR', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Container(
        color: Color(0xFF1E1E1E),
        child: _logs.isEmpty
            ? Center(
                child: Text(
                  'No hay logs aún',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return _buildLogEntry(log);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.arrow_downward),
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    Color iconColor;
    IconData icon;
    
    switch (log.level) {
      case LogLevel.error:
        iconColor = Colors.red;
        icon = Icons.error;
        break;
      case LogLevel.warning:
        iconColor = Colors.orange;
        icon = Icons.warning;
        break;
      case LogLevel.success:
        iconColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case LogLevel.info:
      default:
        iconColor = Colors.blue;
        icon = Icons.info;
        break;
    }

    final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[$timeStr]',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(width: 8),
          Icon(icon, color: iconColor, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });
}

enum LogLevel {
  info,
  success,
  warning,
  error,
}

// Función global para añadir logs desde cualquier parte
void debugLog(String message, {LogLevel level = LogLevel.info}) {
  _DebugLogsViewState.addLog(message, level: level);
  print('[$level] $message'); // También imprimir en consola
}
