import 'package:flutter/material.dart';
import 'package:jankkiller/jankkiller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final JankKillerController _metricsController = JankKillerController(
    onSessionStart: (session) {
      debugPrint('[Mytroll] Session started: ${session.routeName}');
    },
    onSessionEnd: (session) {
      debugPrint('[Mytroll] Session ended: ${session.routeName} - '
          '${session.frameMetrics.length} frames, '
          '${session.durationMs?.toStringAsFixed(0)}ms');
    },
    onFrameMetric: (metric) {
      if (metric.isJanky) {
        debugPrint('[Mytroll] Janky frame #${metric.frameNumber}: '
            '${metric.totalDurationMs.toStringAsFixed(2)}ms');
      }
    },
  );

  @override
  void initState() {
    super.initState();
    // Start collecting after binding is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsController.startCollecting();
    });
  }

  @override
  void dispose() {
    _metricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mytroll Metrics Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorObservers: [_metricsController.navigatorObserver],
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/list': (context) => const ListScreen(),
        '/detail': (context) => const DetailScreen(),
        '/animation': (context) => const AnimationScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen-Flow Profiler Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.speed, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text(
              'Navigate between screens to see\nperformance data in DevTools',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text('List Screen'),
              onPressed: () => Navigator.pushNamed(context, '/list'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.info),
              label: const Text('Detail Screen'),
              onPressed: () => Navigator.pushNamed(context, '/detail'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.animation),
              label: const Text('Animation Screen'),
              onPressed: () => Navigator.pushNamed(context, '/animation'),
            ),
          ],
        ),
      ),
    );
  }
}

class ListScreen extends StatelessWidget {
  const ListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List Screen')),
      body: ListView.builder(
        itemCount: 100,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text('Item ${index + 1}'),
            subtitle: const Text('Tap to view detail'),
            onTap: () => Navigator.pushNamed(context, '/detail'),
          );
        },
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Screen')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article, size: 80, color: Colors.blue),
            SizedBox(height: 24),
            Text('Detail View', style: TextStyle(fontSize: 24)),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This is a detail screen. Performance metrics are being '
                'captured for this screen session.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimationScreen extends StatefulWidget {
  const AnimationScreen({super.key});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animation Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.5 + (_animation.value * 0.5),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withValues(alpha: 0.3),
                          blurRadius: 20 * _animation.value,
                          spreadRadius: 5 * _animation.value,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.flutter_dash,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            const Text(
              'Watch the frame timing chart\nin DevTools while this animates',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
