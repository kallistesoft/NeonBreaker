import 'dart:math';

import 'package:flutter/material.dart';

class Particle {
  Particle(this.pos, this.vel, this.color, this.life, this.size) : maxLife = life;

  Offset pos;
  Offset vel;
  final Color color;
  final double maxLife;
  final double size;
  double life;
}

/// Floating text such as "+120" or "x8 COMBO".
class Popup {
  Popup(this.text, this.pos, this.color, {this.size = 12, this.life = 0.9}) : maxLife = life;

  final String text;
  Offset pos;
  final Color color;
  final double size;
  final double maxLife;
  double life;
}

/// Visual-only effects: sparks, popups and screen shake. Lives in world coordinates.
class Effects {
  final _rng = Random();
  final particles = <Particle>[];
  final popups = <Popup>[];
  double shake = 0;

  /// A ring of sparks bursting from [at].
  void burst(Offset at, Color color, {int count = 10, double speed = 140, double size = 2.4, double life = 0.5}) {
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final v = speed * (0.4 + _rng.nextDouble() * 0.8);
      particles.add(Particle(at, Offset(cos(a), sin(a)) * v, color, life * (0.6 + _rng.nextDouble() * 0.6), size));
    }
    if (particles.length > 600) particles.removeRange(0, particles.length - 600);
  }

  void popup(String text, Offset at, Color color, {double size = 12}) => popups.add(Popup(text, at, color, size: size));

  void addShake(double amount) => shake = min(10, shake + amount);

  Offset get shakeOffset => shake <= 0.05 ? Offset.zero : Offset((_rng.nextDouble() - 0.5) * shake, (_rng.nextDouble() - 0.5) * shake);

  void update(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.pos += p.vel * dt;
      p.vel = p.vel * (1 - 2.5 * dt) + Offset(0, 220 * dt);
    }
    particles.removeWhere((p) => p.life <= 0);
    for (final p in popups) {
      p.life -= dt;
      p.pos += Offset(0, -28 * dt);
    }
    popups.removeWhere((p) => p.life <= 0);
    shake = max(0, shake - 30 * dt);
  }

  void clear() {
    particles.clear();
    popups.clear();
    shake = 0;
  }
}
