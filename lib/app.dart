import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';

import 'gesture/hand_cursor.dart';
import 'gesture/selection_ring.dart';
import 'session/airshift_session.dart';
import 'session/session_state.dart';

class AirShiftApp extends StatefulWidget {
  const AirShiftApp({super.key});

  @override
  State<AirShiftApp> createState() => _AirShiftAppState();
}

class _AirShiftAppState extends State<AirShiftApp> {
  final _session = AirShiftSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Shift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AirShiftColors.bgBase,
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: AirShiftTypography.body,
          headlineMedium: AirShiftTypography.emphasis,
          labelSmall: AirShiftTypography.label,
        ),
      ),
      home: FoundationScreen(session: _session),
    );
  }
}

class FoundationScreen extends StatefulWidget {
  final AirShiftSession session;
  const FoundationScreen({super.key, required this.session});

  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen> {
  Offset _cursorPos = Offset.zero;
  bool _isFist = false;
  SessionState _sState = SessionState.idle;

  @override
  void initState() {
    super.initState();
    widget.session.detector.gestureStream.listen((event) {
      if (mounted) {
        setState(() {
          _cursorPos = Offset(event.x, event.y);
          _isFist = (event.gesture == Gesture.fist);
        });
      }
    });
    widget.session.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _sState = state;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.airplanemode_active,
                  color: AirShiftColors.bluePrimary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Air Shift',
                  style: AirShiftTypography.emphasis.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  _sState == SessionState.idle ? 'Press "Start" to Test Gestures' : 'Gesture Engine Active',
                  style: AirShiftTypography.label,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (_sState == SessionState.idle) {
                      widget.session.start();
                    } else {
                      widget.session.end();
                    }
                  },
                  child: Text(_sState == SessionState.idle ? 'Start Session' : 'End Session'),
                ),
              ],
            ),
          ),
          if (_sState != SessionState.idle)
            HandCursor(
              isFist: _isFist,
              x: _cursorPos.dx,
              y: _cursorPos.dy,
            ),
          if (_sState != SessionState.idle && !_isFist)
            SelectionRing(
              position: _cursorPos,
              onComplete: () {
                debugPrint('Selection Completed!');
              },
            ),
        ],
      ),
    );
  }
}
