import 'dart:math';

class AirShiftNameGenerator {
  static const _adjectives = [
    'swift', 'calm', 'bright', 'cool', 'blue', 'green', 'fast', 'smooth',
    'warm', 'wild', 'soft', 'bold', 'brave', 'sharp', 'clear', 'vivid'
  ];

  static const _nouns = [
    'ocean', 'wind', 'river', 'stone', 'cloud', 'leaf', 'star', 'rain',
    'mountain', 'forest', 'valley', 'bridge', 'path', 'peak', 'wave', 'flame'
  ];

  static String generate() {
    final random = Random();
    final adj = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    return '$adj-$noun';
  }
}
