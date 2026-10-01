import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(home: Scaffold(body: SteeringWheel())));
}

class SteeringWheel extends StatefulWidget {
  const new({super.key});

  @override
  State<SteeringWheel> createState() => _SteeringWheelState();
}

const targetSampleCount = 1000;

class _SteeringWheelState extends State<SteeringWheel> {
  final _sw = Stopwatch();

  int lastMicrosec = 0;

  int currentDeltaMicrosec = 0;
  double? smoothedDeltaMicrosec;
  double? smoothedDeltaHz;

  int sampleCollected = 0;
  List<int> deltaSamples = List.filled(targetSampleCount, 0);

  int sampleHead = 0;

  void onPointerMove(PointerMoveEvent event) {
    if (!_sw.isRunning) {
      _sw.start();
      return;
    }

    final int currentMicrosec = _sw.elapsedMicroseconds;

    setState(() {
      currentDeltaMicrosec = currentMicrosec - lastMicrosec;

      deltaSamples[sampleHead] = currentDeltaMicrosec;

      sampleCollected++;
      sampleHead++;

      if (sampleHead >= targetSampleCount) {
        sampleHead = 0;
      }

      if (sampleCollected >= targetSampleCount) {
        final int totalSampleMicrosec = deltaSamples.reduce((a, b) => a + b);
        smoothedDeltaMicrosec = totalSampleMicrosec / targetSampleCount;
        smoothedDeltaHz = 1_000_000 / smoothedDeltaMicrosec!;
      }
    });

    lastMicrosec = currentMicrosec;
  }

  @override
  void dispose() {
    _sw.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: onPointerMove,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: Container(
            color: Colors.redAccent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Current delta: $currentDeltaMicrosec μs"),
                Text("Current frequency: ${1_000_000 / currentDeltaMicrosec}"),
                Text("Samples collected: $sampleCollected samples"),
                if (smoothedDeltaMicrosec != null)
                  Text("Smoothed delta: $smoothedDeltaMicrosec μs"),
                if (smoothedDeltaHz != null)
                  Text("Smoothed frequency: $smoothedDeltaHz hz"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
