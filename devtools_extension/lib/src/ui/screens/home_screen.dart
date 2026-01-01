import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../../models/screen_session_model.dart';
import '../../services/session_manager.dart';
import 'comparison_view.dart';
import 'session_detail_view.dart';
import 'session_list_view.dart';

/// Main home screen for the mytroll_metrics DevTools extension.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SessionManager _sessionManager = SessionManager();
  String? _selectedSessionId; // Store ID instead of reference
  ScreenSessionModel? _baselineSession;
  bool _isConnected = false;
  bool _isConnecting = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    try {
      await _sessionManager.initialize();
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to VM Service...'),
            ],
          ),
        ),
      );
    }

    if (!_isConnected) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              const Text('Failed to connect to VM Service'),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isConnecting = true);
                  _initializeConnection();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('JankKiller Screen-Flow Profiler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _sessionManager.refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Sessions',
            onPressed: () {
              _sessionManager.clearSessions();
              setState(() {
                _selectedSessionId = null;
                _baselineSession = null;
              });
            },
          ),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          if (_selectedSessionId != null)
            Builder(
              builder: (context) {
                final selectedSession = _sessionManager.sessions.firstWhere(
                  (s) => s.sessionId == _selectedSessionId,
                  orElse: () => _sessionManager.sessions.first,
                );
                return TextButton.icon(
                  icon: const Icon(Icons.bookmark_outline),
                  label: const Text('Set Baseline'),
                  onPressed: () {
                    setState(() => _baselineSession = selectedSession);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Baseline set: ${selectedSession.routeName}'),
                      ),
                    );
                  },
                );
              },
            ),
          if (_baselineSession != null &&
              _selectedSessionId != null &&
              _baselineSession!.sessionId != _selectedSessionId)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare'),
                onPressed: () => _showComparison(context),
              ),
            ),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export',
            onPressed: _exportSessions,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Baseline',
            onPressed: _importBaseline,
          ),
        ],
      ),
      body: Row(
        children: [
          // Session List Panel
          SizedBox(
            width: 320,
            child: ListenableBuilder(
              listenable: _sessionManager,
              builder: (context, _) {
                // Find selected session from current sessions list
                final selectedSession = _selectedSessionId != null
                    ? _sessionManager.sessions
                        .where((s) => s.sessionId == _selectedSessionId)
                        .firstOrNull
                    : null;

                return SessionListView(
                  sessionManager: _sessionManager,
                  selectedSession: selectedSession,
                  onSessionSelected: (ScreenSessionModel? session) {
                    setState(() => _selectedSessionId = session?.sessionId);
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          // Session Detail Panel
          Expanded(
            child: ListenableBuilder(
              listenable: _sessionManager,
              builder: (context, child) {
                if (_selectedSessionId == null) {
                  return const Center(
                    child: Text(
                      'Select a session to view details',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Find the current session from the manager by ID
                final currentSession = _sessionManager.sessions
                    .where((s) => s.sessionId == _selectedSessionId)
                    .firstOrNull;

                // If session not found, clear selection and show empty state
                if (currentSession == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _selectedSessionId = null);
                    }
                  });
                  return const Center(
                    child: Text(
                      'Session no longer available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Rebuild detail view with latest session data
                return SessionDetailView(
                  session: currentSession,
                  sessionManager: _sessionManager,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showComparison(BuildContext context) {
    if (_baselineSession == null || _selectedSessionId == null) return;

    final selectedSession = _sessionManager.sessions
        .where((s) => s.sessionId == _selectedSessionId)
        .firstOrNull;

    if (selectedSession == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ComparisonView(
          baseline: _baselineSession!,
          candidate: selectedSession,
        ),
      ),
    );
  }

  void _exportSessions() {
    try {
      final data = _sessionManager.exportSessions();
      final jsonString = jsonEncode(data);

      // Use web-specific download logic
      final blob = html.Blob([jsonString], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download',
            'mytroll_profile_${DateTime.now().millisecondsSinceEpoch}.json')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessions exported successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _importBaseline() {
    final uploadInput = html.FileUploadInputElement()..accept = '.json';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final reader = html.FileReader();
      reader.readAsText(files[0]);
      reader.onLoadEnd.listen((e) {
        try {
          final content = reader.result as String;
          final Map<String, dynamic> data = jsonDecode(content);
          final sessions = _sessionManager.importSessions(data);

          if (sessions.isNotEmpty) {
            setState(() {
              _baselineSession = sessions.first;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Imported baseline: ${_baselineSession!.routeName}')),
              );
            }
          }
        } catch (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Import failed: Invalid JSON format')),
            );
          }
        }
      });
    });
  }
}
