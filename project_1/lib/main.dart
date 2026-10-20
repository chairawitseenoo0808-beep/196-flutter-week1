import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() => runApp(const DinoRunnerApp());

class DinoRunnerApp extends StatelessWidget {
  const DinoRunnerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const DinoGame(),
      );
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// skeleton = โครงกระดูกยักษ์ (ม้วนตัวลอด หรือ กระโดด 2 ครั้งข้าม)
enum ObjectType { skeleton, meteor, meat }

/// หน้าจอของแอป: หน้าแรก -> เลือกสกิน -> เลือกแพลตฟอร์ม -> เกม
enum AppScreen { home, skins, platform, credits, game }

/// แพลตฟอร์มที่ผู้เล่นเลือก
enum GamePlatform { mobile, pc }

// ===========================================================================
// ข้อมูลผู้จัดทำ  >>> แก้ข้อมูลตรงนี้เพื่อให้แสดงในหน้า "ผู้จัดทำ" <<<
//
// วิธีใส่รูป:
//   1) สร้างโฟลเดอร์ assets/images/ ไว้ในโปรเจกต์ Flutter (ระดับเดียวกับ lib/)
//   2) นำรูปไปวาง เช่น assets/images/dev1.png และ assets/images/dev2.png
//   3) เปิดไฟล์ pubspec.yaml แล้วเพิ่ม (ย่อหน้าต้องตรงกับตัวอย่าง):
//        flutter:
//          assets:
//            - assets/images/dev1.png
//            - assets/images/dev2.png
//      (หรือใส่ทั้งโฟลเดอร์: - assets/images/)
//   4) แก้ imageAsset ด้านล่างให้ตรงกับชื่อไฟล์
//   5) รันใหม่ด้วย flutter pub get แล้ว flutter run (ถ้ารันอยู่ให้ Stop แล้วรันใหม่)
// ถ้ายังไม่ใส่รูป เกมจะแสดงไอคอนรูปคนแทน ไม่ error
// ===========================================================================
class Developer {
  const Developer({
    required this.firstName,
    required this.lastName,
    required this.studentId,
    required this.imageAsset,
  });
  final String firstName, lastName, studentId, imageAsset;
}

const List<Developer> developers = [
  Developer(
    firstName: 'ธนพงษ์',
    lastName: 'แก้วงาม',
    studentId: '016840641013-9',
    imageAsset: 'assets/images/Few.jpg',
  ),
  Developer(
    firstName: 'ชัยรวิชญ์',
    lastName: 'สีหนู',
    studentId: '016840641019-6',
    imageAsset: 'assets/images/Dew.png',
  ),
];

/// วัตถุบนแทร็ก: lane = -1,0,1 | d = ระยะห่างจากผู้เล่น (ข้างหน้า = บวก)
/// h = ความสูงจากพื้น (ใช้กับเนื้อและอุกกาบาตที่กำลังตก)
class GameObject {
  GameObject(this.type, this.lane, this.d,
      {this.h = 0, this.vFall = 0, this.variant = 0});
  final ObjectType type;
  final int lane;
  double d, h;
  final double vFall;
  final int variant;
  bool removed = false, hit = false, landed = false;
  double impactT = 0;

  /// ความยาวตามแนวลึก
  double get len {
    switch (type) {
      case ObjectType.skeleton:
        return 50;
      case ObjectType.meteor:
        return 60;
      case ObjectType.meat:
        return 30;
    }
  }

  /// ช่วงความสูงที่วัตถุกินพื้นที่ (ใช้ตรวจชน)
  /// โครงกระดูก: ใต้ 48 ว่าง (ม้วนตัวลอดได้), สูงถึง 135
  /// กระโดดครั้งเดียวสูงสุด ~100 จึงไม่พ้น ต้องกระโดด 2 ครั้ง
  double get bottom {
    switch (type) {
      case ObjectType.skeleton:
        return 48;
      case ObjectType.meteor:
        return math.max(0.0, h);
      case ObjectType.meat:
        return h - 15;
    }
  }

  double get top {
    switch (type) {
      case ObjectType.skeleton:
        return 135;
      case ObjectType.meteor:
        return math.max(0.0, h) + 45;
      case ObjectType.meat:
        return h + 15;
    }
  }
}

class Pop {
  Pop(this.lane, this.y);
  final double lane;
  final double y;
  double life = 0.7;
}

/// สกินไดโนเสาร์
class SkinDef {
  const SkinDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.price,
    required this.body,
    required this.light,
    required this.dark,
    required this.accent,
    this.special = false,
  });
  final int id;
  final String name, desc;
  final int price;
  final Color body, light, dark, accent;
  final bool special;
}

const List<SkinDef> skins = [
  SkinDef(
    id: 0,
    name: 'ไดโนคลาสสิก',
    desc: 'นักวิ่งสีเขียวสุดคลาสสิก',
    price: 0,
    body: Color(0xFF299B43),
    light: Color(0xFF3DBB5A),
    dark: Color(0xFF176B35),
    accent: Color(0xFFFFD45C),
  ),
  SkinDef(
    id: 1,
    name: 'มังกรเพลิง',
    desc: 'ปีกลุกเป็นไฟ เขาแหลม เปลวไฟบนหัว',
    price: 2000,
    body: Color(0xFFD9402B),
    light: Color(0xFFFF7B35),
    dark: Color(0xFF8E1F14),
    accent: Color(0xFFFFC65A),
  ),
  SkinDef(
    id: 2,
    name: 'มังกรน้ำแข็ง',
    desc: 'มงกุฎคริสตัลและปีกน้ำแข็งใส',
    price: 2000,
    body: Color(0xFF4FA8D8),
    light: Color(0xFFBFE9FF),
    dark: Color(0xFF2A6C9C),
    accent: Color(0xFFE8FAFF),
  ),
  SkinDef(
    id: 3,
    name: 'เอลฟ์แห่งป่า',
    desc: 'หูแหลมเอลฟ์ มงกุฎใบไม้ศักดิ์สิทธิ์',
    price: 2000,
    body: Color(0xFF2E8B57),
    light: Color(0xFF8FD98B),
    dark: Color(0xFF1B5E3A),
    accent: Color(0xFFFFE16A),
  ),
  SkinDef(
    id: 4,
    name: 'อัศวินทองคำ',
    desc: 'หมวกเกราะทอง เกราะอก และขนนกสีแดง',
    price: 2000,
    body: Color(0xFF5C8A3A),
    light: Color(0xFFD9DEE8),
    dark: Color(0xFF3A5A28),
    accent: Color(0xFFFFC847),
  ),
  SkinDef(
    id: 5,
    name: 'จอมเวทมังกร',
    desc: 'หมวกพ่อมดดาวทอง พร้อมประกายเวทมนตร์',
    price: 2000,
    body: Color(0xFF7B4FD6),
    light: Color(0xFFB38CFF),
    dark: Color(0xFF4A2A8F),
    accent: Color(0xFFFFE16A),
  ),
  SkinDef(
    id: 6,
    name: 'ราชาสายฟ้า',
    desc: 'สายฟ้าฟาดรอบตัว ผมสายฟ้า (สกินพิเศษ)',
    price: 4000,
    body: Color(0xFF2B3A67),
    light: Color(0xFF4A6BD6),
    dark: Color(0xFF141C3A),
    accent: Color(0xFFFFF176),
    special: true,
  ),
  SkinDef(
    id: 7,
    name: 'เจ้าแห่งจักรวาล',
    desc: 'ดวงดาวโคจร ฮาโล และกาแล็กซีบนตัว (สกินพิเศษ)',
    price: 4000,
    body: Color(0xFF2A1A5E),
    light: Color(0xFF6A4BD8),
    dark: Color(0xFF150B38),
    accent: Color(0xFFFF8AE0),
    special: true,
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// สุ่มแบบคงที่ (ค่าเดิมทุกครั้งสำหรับ i, salt เดิม) ได้ค่า 0..1
double hash01(int i, int salt) {
  final double v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

void paintMeat(Canvas canvas, double x, double y, double size) {
  final Paint red = Paint()..color = const Color(0xFFE94B4B);
  final Paint bone = Paint()..color = const Color(0xFFFFF1CF);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, y), width: size * 0.75, height: size * 0.55),
          Radius.circular(size * 0.2)),
      red);
  canvas.drawCircle(Offset(x - size * 0.22, y - size * 0.12), size * 0.23, red);
  canvas.drawCircle(Offset(x + size * 0.23, y - size * 0.12), size * 0.21, red);
  canvas.drawLine(
      Offset(x + size * 0.22, y + size * 0.12),
      Offset(x + size * 0.48, y + size * 0.28),
      Paint()
        ..color = bone.color
        ..strokeWidth = size * 0.13
        ..strokeCap = StrokeCap.round);
  canvas.drawCircle(
      Offset(x + size * 0.48, y + size * 0.28), size * 0.12, bone);
}

class MeatIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintMeat(canvas, size.width * 0.42, size.height * 0.45, size.width * 0.9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Dino sprite (ใช้ร่วมกันทั้งในเกมและหน้าเลือกสกิน)
// พิกัด: จุด (0,0) = กึ่งกลางเท้า, ขึ้นด้านบน = ค่าลบ
// ---------------------------------------------------------------------------

class DinoSprite {
  static int al(double v) => v.clamp(0.0, 255.0).round();

  static void glow(Canvas canvas, Offset c, double r, Color color, int a) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withAlpha(a.clamp(0, 255).toInt()),
          color.withAlpha(0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  static void star4(Canvas canvas, Offset c, double r, Paint paint) {
    final Path p = Path();
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4 - math.pi / 2;
      final double rr = i.isEven ? r : r * 0.35;
      final double x = c.dx + math.cos(a) * rr;
      final double y = c.dy + math.sin(a) * rr;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    canvas.drawPath(p, paint);
  }

  /// t = เวลาโลก, phase = เฟสก้าวขา, air = 0..1 (ลอยกลางอากาศ),
  /// roll = 0..1 (ระดับการม้วนตัว), rollAngle = มุมหมุนของลูกบอล
  static void draw(
    Canvas canvas,
    SkinDef s, {
    required double t,
    required double phase,
    required double air,
    required double roll,
    required double rollAngle,
    required bool run,
  }) {
    final double cy = -42 + 22 * roll;

    // ออร่าด้านหลังสำหรับสกินพิเศษ
    if (s.special) {
      final double pulse = 0.85 + 0.15 * math.sin(t * 5);
      glow(canvas, Offset(0, cy), 58 * pulse, s.accent, 95);
    }

    // ตัวปกติ (เฟดออกเมื่อม้วนตัว)
    if (roll < 0.99) {
      final bool fade = roll > 0.01;
      if (fade) {
        canvas.saveLayer(
            null,
            Paint()
              ..color = Color.fromARGB(al(255 * (1 - roll)), 255, 255, 255));
        canvas.scale(1.0, 1.0 - 0.4 * roll);
      }
      standing(canvas, s, t, phase, air, run);
      if (fade) canvas.restore();
    }

    // ลูกบอลม้วนตัว (เฟดเข้า)
    if (roll > 0.01) {
      canvas.saveLayer(null,
          Paint()..color = Color.fromARGB(al(255 * roll), 255, 255, 255));
      ball(canvas, s, rollAngle);
      canvas.restore();
    }

    fx(canvas, s, t, cy);
  }

  static void ball(Canvas canvas, SkinDef s, double rollAngle) {
    final Paint body = Paint()..color = s.body;
    final Paint light = Paint()..color = s.light;
    final Paint spike = Paint()
      ..color = (s.id == 0 || s.id == 3 || s.id == 4 || s.id == 5)
          ? s.dark
          : s.accent;
    canvas.save();
    canvas.translate(0, -21);
    canvas.rotate(rollAngle);
    canvas.drawCircle(Offset.zero, 21, body);
    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 5);
      canvas.drawPath(
        Path()
          ..moveTo(-5, -19)
          ..lineTo(0, -29)
          ..lineTo(5, -19)
          ..close(),
        spike,
      );
      canvas.restore();
    }
    canvas.drawCircle(const Offset(7, -6), 4, light);
    if (s.id != 0) {
      canvas.drawCircle(
          Offset.zero,
          13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = s.accent.withAlpha(190));
    }
    canvas.restore();
  }

  static void wings(Canvas canvas, SkinDef s, double t, double air) {
    final double flap = math.sin(t * (6.0 + 10.0 * air)) * (0.3 + 0.55 * air);
    final Paint fill = Paint()
      ..color = s.id == 2 ? s.light.withAlpha(210) : s.dark;
    final Paint edge = Paint()
      ..color = s.accent.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    for (final double side in const [-1.0, 1.0]) {
      final Path p = Path()
        ..moveTo(side * 18, -58)
        ..lineTo(side * (48 + 10 * flap), -92 - 24 * flap)
        ..lineTo(side * (40 + 4 * flap), -70 - 8 * flap)
        ..lineTo(side * (60 + 10 * flap), -72 - 16 * flap)
        ..lineTo(side * (44 + 4 * flap), -56 - 4 * flap)
        ..lineTo(side * (54 + 8 * flap), -44 - 8 * flap)
        ..lineTo(side * 20, -44)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, edge);
    }
  }

  static void standing(Canvas canvas, SkinDef s, double t, double phase,
      double air, bool run) {
    final Paint body = Paint()..color = s.body;
    final Paint light = Paint()..color = s.light;
    final Paint dark = Paint()..color = s.dark;

    // เด้งตัวตามจังหวะก้าว / หายใจตอนยืนนิ่ง
    final double bob = run
        ? -math.sin(phase).abs() * 3.0 * (1.0 - air)
        : math.sin(t * 2.5) * 1.2;
    final double sway = run
        ? math.sin(phase) * 6.0 * (1.0 - air)
        : math.sin(t * 2.0) * 3.0;

    if (s.id == 1 || s.id == 2) wings(canvas, s, t, air);

    // ขา: ก้าวสลับ ยกเท้าตามเฟส / ตอนลอยพับขาขึ้น
    for (int i = 0; i < 2; i++) {
      final double x = i == 0 ? -17 : 5;
      final double st = math.sin(phase + i * math.pi);
      final double lift =
          run ? math.max(0.0, st) * 8.0 * (1.0 - air) + 9.0 * air : 9.0 * air;
      final double hgt = 16.0 - 4.0 * air;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, -hgt - lift, 12, hgt), const Radius.circular(3)),
          dark);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - 2, -5 - lift, 16, 5),
              const Radius.circular(2.5)),
          dark);
    }

    canvas.save();
    canvas.translate(0, bob);

    // ลำตัว
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -42), width: 50, height: 58),
        body);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(-9, -52), width: 14, height: 24),
        Paint()..color = Colors.white.withAlpha(28));

    // ลวดลายตามสกิน
    if (s.id == 4) {
      final Rect plate =
          Rect.fromCenter(center: const Offset(0, -40), width: 36, height: 40);
      canvas.drawOval(plate, Paint()..color = s.light);
      canvas.drawOval(
          plate,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = s.accent);
      final Paint cross = Paint()
        ..color = s.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(0, -54), const Offset(0, -26), cross);
      canvas.drawLine(const Offset(-10, -42), const Offset(10, -42), cross);
    } else if (s.id == 6) {
      canvas.drawPath(
          Path()
            ..moveTo(3, -62)
            ..lineTo(-6, -44)
            ..lineTo(0, -44)
            ..lineTo(-4, -26)
            ..lineTo(8, -48)
            ..lineTo(1, -48)
            ..close(),
          Paint()..color = s.accent);
    } else if (s.id == 7) {
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(-6, -46), width: 30, height: 20),
          Paint()..color = s.light.withAlpha(110));
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(8, -36), width: 24, height: 16),
          Paint()..color = s.accent.withAlpha(70));
      for (int i = 0; i < 12; i++) {
        final double px = (hash01(i, 21) - 0.5) * 40;
        final double py = -42 + (hash01(i, 22) - 0.5) * 48;
        final double nx = px / 25;
        final double ny = (py + 42) / 29;
        if (nx * nx + ny * ny > 0.85) continue;
        final double tw = 0.5 + 0.5 * math.sin(t * 4 + i);
        canvas.drawCircle(Offset(px, py), (0.8 + hash01(i, 23) * 1.4) * (0.5 + tw),
            Paint()..color = Colors.white.withAlpha(al(120 + 135 * tw)));
      }
    }

    // หาง (ส่ายนุ่มๆ)
    canvas.drawPath(
      Path()
        ..moveTo(-9, -30)
        ..quadraticBezierTo(-4 + sway * 0.4, -14, sway, -2)
        ..quadraticBezierTo(4 + sway * 0.4, -14, 9, -30)
        ..close(),
      light,
    );

    // หนามกลางหลัง
    final Paint sp = (s.id == 1 || s.id == 2 || s.id == 6 || s.id == 7)
        ? (Paint()..color = s.accent)
        : dark;
    for (int i = 0; i < 4; i++) {
      final double sy = -62.0 + i * 14.0;
      canvas.drawPath(
        Path()
          ..moveTo(-7, sy)
          ..lineTo(0, sy - 9)
          ..lineTo(7, sy)
          ..close(),
        sp,
      );
    }

    // แขน: แกว่งสวนกับขา / ยกขึ้นตอนลอย
    final double swing = run ? math.sin(phase + math.pi) * 3.0 * (1.0 - air) : 0.0;
    final double armUp = 7.0 * air;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(-27, -44 + swing - armUp), width: 12, height: 20),
        body);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(27, -44 - swing - armUp), width: 12, height: 20),
        body);

    // หัว
    final double hy = -76.0 + (run ? math.sin(phase).abs() * 1.2 : 0.0);
    canvas.drawCircle(Offset(0, hy), 16, body);
    final Paint eye = Paint()
      ..color = (s.id == 6 || s.id == 7)
          ? s.accent
          : const Color(0xFF152B1E);
    canvas.drawCircle(Offset(-13, hy - 2), 3, eye);
    canvas.drawCircle(Offset(13, hy - 2), 3, eye);

    accessories(canvas, s, t, hy, sway, phase, run, dark, light);

    canvas.restore();
  }

  static void accessories(Canvas canvas, SkinDef s, double t, double hy,
      double sway, double phase, bool run, Paint dark, Paint light) {
    final Paint acc = Paint()..color = s.accent;
    switch (s.id) {
      case 0:
        canvas.drawPath(
          Path()
            ..moveTo(-5, hy - 14)
            ..lineTo(0, hy - 23)
            ..lineTo(5, hy - 14)
            ..close(),
          dark,
        );
        break;
      case 1:
        // เขา
        canvas.drawPath(
            Path()
              ..moveTo(-10, hy - 12)
              ..lineTo(-18, hy - 31)
              ..lineTo(-4, hy - 14)
              ..close(),
            acc);
        canvas.drawPath(
            Path()
              ..moveTo(10, hy - 12)
              ..lineTo(18, hy - 31)
              ..lineTo(4, hy - 14)
              ..close(),
            acc);
        // เปลวไฟบนหัว
        for (int j = -1; j <= 1; j++) {
          final double fh = (j == 0 ? 15.0 : 10.0) + math.sin(t * 16 + j * 2) * 4;
          final double bx = j * 5.0;
          canvas.drawPath(
              Path()
                ..moveTo(bx - 4, hy - 15)
                ..lineTo(bx, hy - 15 - fh)
                ..lineTo(bx + 4, hy - 15)
                ..close(),
              Paint()..color = const Color(0xFFFF7B35));
          canvas.drawPath(
              Path()
                ..moveTo(bx - 2, hy - 15)
                ..lineTo(bx, hy - 15 - fh * 0.6)
                ..lineTo(bx + 2, hy - 15)
                ..close(),
              Paint()..color = const Color(0xFFFFE08A));
        }
        break;
      case 2:
        // มงกุฎคริสตัล
        const List<double> xs = [-9, 0, 9];
        const List<double> hs = [16, 25, 16];
        for (int i = 0; i < 3; i++) {
          final Path c = Path()
            ..moveTo(xs[i] - 4.5, hy - 13)
            ..lineTo(xs[i], hy - 13 - hs[i])
            ..lineTo(xs[i] + 4.5, hy - 13)
            ..close();
          canvas.drawPath(c, acc);
          canvas.drawPath(
              c,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.3
                ..color = s.light);
        }
        final double tw = 0.5 + 0.5 * math.sin(t * 4);
        star4(canvas, Offset(15, hy - 24), 4 + 3 * tw,
            Paint()..color = Colors.white.withAlpha(al(120 + 135 * tw)));
        break;
      case 3:
        // หูเอลฟ์
        canvas.drawPath(
            Path()
              ..moveTo(-14, hy - 6)
              ..lineTo(-32, hy - 16)
              ..lineTo(-14, hy + 5)
              ..close(),
            light);
        canvas.drawPath(
            Path()
              ..moveTo(14, hy - 6)
              ..lineTo(32, hy - 16)
              ..lineTo(14, hy + 5)
              ..close(),
            light);
        // มงกุฎใบไม้
        for (int i = 0; i < 5; i++) {
          final double ang = -math.pi + (i + 1) * math.pi / 6;
          canvas.save();
          canvas.translate(math.cos(ang) * 15, hy + math.sin(ang) * 15);
          canvas.rotate(ang + math.pi / 2);
          canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 7, height: 15),
              Paint()
                ..color = i.isEven
                    ? const Color(0xFF58C46A)
                    : const Color(0xFF8FD98B));
          canvas.restore();
        }
        canvas.drawCircle(Offset(0, hy - 17), 2.6, acc);
        break;
      case 4:
        // หมวกเกราะ + ขนนก
        final double ps = math.sin(t * 5) * 3 + (run ? math.sin(phase) * 2 : 0);
        canvas.drawPath(
            Path()
              ..moveTo(-3, hy - 17)
              ..quadraticBezierTo(ps - 4, hy - 30, ps + 2, hy - 38)
              ..quadraticBezierTo(ps + 8, hy - 28, 5, hy - 17)
              ..close(),
            Paint()..color = const Color(0xFFE2323C));
        canvas.drawArc(Rect.fromCircle(center: Offset(0, hy), radius: 17.5),
            math.pi, math.pi, true, acc);
        canvas.drawRect(Rect.fromLTWH(-17.5, hy - 1, 35, 4),
            Paint()..color = const Color(0xFFC8941E));
        canvas.drawLine(
            Offset(0, hy - 17), Offset(0, hy - 1),
            Paint()
              ..color = const Color(0xFFC8941E)
              ..strokeWidth = 2);
        break;
      case 5:
        // หมวกพ่อมด
        canvas.drawPath(
            Path()
              ..moveTo(-17, hy - 8)
              ..quadraticBezierTo(-4, hy - 30, 3 + sway * 0.3, hy - 52)
              ..quadraticBezierTo(8, hy - 30, 17, hy - 8)
              ..close(),
            Paint()..color = const Color(0xFF4A2A8F));
        canvas.drawOval(
            Rect.fromCenter(center: Offset(0, hy - 8), width: 46, height: 10),
            Paint()..color = const Color(0xFF3A1F70));
        canvas.drawRect(Rect.fromLTWH(-13, hy - 15, 26, 5), acc);
        star4(canvas, Offset(2, hy - 30), 5, acc);
        final double tw = 0.5 + 0.5 * math.sin(t * 6);
        glow(canvas, Offset(3 + sway * 0.3, hy - 52), 8 + 4 * tw, s.accent, 200);
        break;
      case 6:
        // ผมสายฟ้า
        final double k = 1.0 + 0.12 * math.sin(t * 20);
        canvas.drawPath(
            Path()
              ..moveTo(-12, hy - 12)
              ..lineTo(-10, hy - 12 - 14 * k)
              ..lineTo(-4, hy - 15)
              ..lineTo(0, hy - 12 - 20 * k)
              ..lineTo(4, hy - 15)
              ..lineTo(10, hy - 12 - 14 * k)
              ..lineTo(12, hy - 12)
              ..close(),
            acc);
        break;
      case 7:
        // ฮาโล + ดาวโคจรรอบหัว
        canvas.drawOval(
            Rect.fromCenter(center: Offset(0, hy - 21), width: 40, height: 10),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = s.accent.withAlpha(al(170 + 70 * math.sin(t * 4))));
        final Offset o = Offset(math.cos(t * 2.4) * 20, hy - 21 + math.sin(t * 2.4) * 5);
        glow(canvas, o, 7, Colors.white, 200);
        canvas.drawCircle(o, 2.4, Paint()..color = Colors.white);
        canvas.drawPath(
            Path()
              ..moveTo(-5, hy - 14)
              ..lineTo(0, hy - 23)
              ..lineTo(5, hy - 14)
              ..close(),
            acc);
        break;
    }
  }

  /// เอฟเฟกต์รอบตัว (อนุภาค / สายฟ้า / ดาวโคจร)
  static void fx(Canvas canvas, SkinDef s, double t, double cy) {
    if (s.id >= 1 && s.id <= 5) {
      final bool up = s.id == 1 || s.id == 5;
      for (int i = 0; i < 5; i++) {
        final double ph = (t * 0.7 + i * 0.2) % 1.0;
        final double x = math.sin(i * 2.3 + t * 1.3) * (22.0 + i * 2.0);
        final double y = up ? cy - 15 - ph * 55 : cy - 45 + ph * 60;
        final double r = (1.2 + hash01(i, 31) * 1.6) * (1.0 - ph * 0.6);
        canvas.drawCircle(
            Offset(x, y),
            r,
            Paint()
              ..color = s.accent.withAlpha(al(220 * math.sin(ph * math.pi))));
      }
    } else if (s.id == 6) {
      final int seed = (t * 16).floor();
      for (int k = 0; k < 3; k++) {
        final double ang = hash01(seed * 3 + k, 41) * 2 * math.pi;
        Offset cur = Offset(math.cos(ang) * 26, cy + math.sin(ang) * 30);
        final Path path = Path()..moveTo(cur.dx, cur.dy);
        for (int seg = 0; seg < 4; seg++) {
          final double a2 = ang + (hash01(seed * 3 + k, 42 + seg) - 0.5) * 1.3;
          cur = Offset(cur.dx + math.cos(a2) * 9, cur.dy + math.sin(a2) * 9);
          path.lineTo(cur.dx, cur.dy);
        }
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.5
              ..strokeJoin = StrokeJoin.round
              ..color = s.accent.withAlpha(90));
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white);
      }
    } else if (s.id == 7) {
      for (int i = 0; i < 6; i++) {
        final double a = t * 2.2 + i * math.pi / 3;
        for (int j = 4; j >= 0; j--) {
          final double aa = a - j * 0.13;
          final Offset c = Offset(math.cos(aa) * 38, cy - 6 + math.sin(aa) * 13);
          final double depth = 0.6 + 0.4 * math.sin(aa);
          if (j == 0) {
            glow(canvas, c, 8 * depth, s.accent, 160);
            star4(canvas, c, 4.5 * depth, Paint()..color = Colors.white);
          } else {
            canvas.drawCircle(
                c,
                2.2 * depth * (1.0 - j * 0.18),
                Paint()..color = s.accent.withAlpha(al(150 * (1 - j / 5))));
          }
        }
      }
    }
  }
}

/// ตัวอย่างสกินแบบเคลื่อนไหว (วิ่ง -> กระโดด -> ม้วนตัว วนไปเรื่อยๆ)
class SkinPreviewPainter extends CustomPainter {
  SkinPreviewPainter(this.skin, this.t);
  final SkinDef skin;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double sc = size.height / 150.0;
    final double c = (t + skin.id * 0.6) % 4.2;
    double air = 0, roll = 0, lift = 0;
    if (c >= 2.4 && c < 3.1) {
      final double k = (c - 2.4) / 0.7;
      lift = math.sin(k * math.pi) * 30;
      air = math.sin(k * math.pi).clamp(0.0, 1.0).toDouble();
    } else if (c >= 3.1 && c < 3.8) {
      final double k = (c - 3.1) / 0.7;
      roll = (math.sin(k * math.pi) * 2.5).clamp(0.0, 1.0).toDouble();
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height - 6),
            width: 50 * sc * (1.0 - lift / 90),
            height: 9 * sc),
        Paint()..color = const Color(0x55000000));
    canvas.save();
    canvas.translate(size.width / 2, size.height - 6 - lift * sc);
    canvas.scale(sc);
    DinoSprite.draw(canvas, skin,
        t: t,
        phase: t * 11,
        air: air,
        roll: roll,
        rollAngle: t * 16,
        run: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SkinPreviewPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Game
// ---------------------------------------------------------------------------

class DinoGame extends StatefulWidget {
  const DinoGame({super.key});
  @override
  State<DinoGame> createState() => _DinoGameState();
}

class _DinoGameState extends State<DinoGame>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  Duration previousTime = Duration.zero;
  final math.Random random = math.Random();
  final AudioPlayer bgmPlayer = AudioPlayer();
  final List<GameObject> objects = [];
  final List<Pop> pops = [];

  AppScreen screen = AppScreen.home;
  GamePlatform platform = GamePlatform.mobile;

  bool running = false, gameOver = false, paused = false;
  bool jumping = false, rolling = false, rollQueued = false;

  /// กดปุ่มม้วนตัวค้างอยู่หรือไม่
  bool rollHeld = false;

  /// score = ระยะทางที่วิ่งได้ (เมตร)
  int score = 0, lives = 3, bestScore = 0;

  /// เนื้อที่เก็บได้ในรอบนี้ / เนื้อสะสมทั้งหมด (ค่าเงิน ไม่รีเซ็ตตอนเริ่มเกมใหม่)
  int meatCollected = 0, totalMeat = 0;
  double elapsed = 0, dist = 0, worldTime = 0;
  double damageFlash = 0, invuln = 0;

  // สกิน
  final Set<int> ownedSkins = {0};
  int selectedSkin = 0;

  // ความเร็ววิ่ง (หน่วยโลก/วินาที) เพิ่มทุกๆ 300 เมตร
  static const double baseSpeed = 700;
  static const double maxSpeed = 4500;
  static const double speedStep = 100;
  static const int speedUpEvery = 300;
  static const double unitsPerMeter = 100;
  double speed = baseSpeed;
  int speedLevel = 0;
  double speedUpTimer = 0;

  // เลน
  int targetLane = 0;
  double laneX = 0;
  int lastSafe = 0;

  // กระโดด (ค่าบวก = ลอยสูงขึ้น)
  static const int maxJumps = 2;
  static const double jumpVelocity = 720.0;
  static const double doubleJumpVelocity = 640.0;
  static const double gravityUp = 2600.0;
  static const double gravityDown = 3600.0;
  static const double flipDuration = 0.55;
  static const double rollMinDuration = 0.4;

  int jumpCount = 0;
  double jumpY = 0, velocityY = 0;
  double flipProgress = 1.0;
  double dinoTilt = 0;
  double stretch = 0;
  double rollTimer = 0;

  // แอนิเมชันไดโนเสาร์
  double runPhase = 0, airBlend = 0, rollBlend = 0, rollAngle = 0;

  // สปาวน์
  static const double spawnD = 2800;
  double spawnGap = 450;
  double meteorTimer = 6;

  // ปัดหน้าจอ (รองรับหลายนิ้ว เพื่อกดปุ่มม้วนตัวค้างพร้อมปัดเปลี่ยนเลน)
  final Map<int, Offset> swipeAcc = {};
  final Set<int> uiPointers = {};

  @override
  void initState() {
    super.initState();
    ticker = createTicker(updateGame)..start();
  }

  @override
  void dispose() {
    bgmPlayer.dispose();
    ticker.dispose();
    super.dispose();
  }
Future<void> startBGM() async {
  await bgmPlayer.setReleaseMode(ReleaseMode.loop); // เล่นวนลูป
  await bgmPlayer.play(AssetSource('audio/Dainosong.mp3'), volume: 0.5); // เล่นเพลง Dainosong.mp3
}

Future<void> stopBGM() async {
  await bgmPlayer.stop();
}
  // ------------------------------------------------------------------ loop

  void updateGame(Duration now) {
    double dt = 0;
    if (previousTime != Duration.zero) {
      dt = ((now - previousTime).inMicroseconds / 1000000)
          .clamp(0.0, 0.035)
          .toDouble();
    }
    previousTime = now;
    if (!mounted) return;

    // เมนูต่างๆ: ฉากเลื่อนช้าๆ + ภูเขาไฟระเบิดทุก 3 วิ
    if (screen != AppScreen.game) {
      setState(() {
        dist += 90 * dt;
        worldTime += dt;
      });
      return;
    }
    if (paused) return;

    // รอเริ่มวิ่ง หรือเกมจบ: ฉากนิ่ง แต่ภูเขาไฟยังระเบิดต่อ
    if (!running || gameOver) {
      setState(() {
        worldTime += dt;
      });
      return;
    }

    setState(() {
      elapsed += dt;
      worldTime += dt;
      damageFlash = math.max(0.0, damageFlash - dt).toDouble();
      invuln = math.max(0.0, invuln - dt).toDouble();
      speedUpTimer = math.max(0.0, speedUpTimer - dt).toDouble();

      // เพิ่มความเร็วทุกๆ 300 เมตร
      final int level = score ~/ speedUpEvery;
      if (level > speedLevel) {
        speedLevel = level;
        speedUpTimer = 2.2;
      }
      speed = math.min(maxSpeed, baseSpeed + level * speedStep).toDouble();
      dist += speed * dt;

      // คะแนน = ระยะทาง (เมตร)
      score = (dist / unitsPerMeter).floor();

      // เลื่อนเลนแบบนุ่ม (exponential smoothing)
      laneX += (targetLane - laneX) * (1.0 - math.exp(-13.0 * dt));
      if ((targetLane - laneX).abs() < 0.001) laneX = targetLane.toDouble();

      updateJump(dt);

      // แถวสิ่งกีดขวาง/เนื้อ
      spawnGap -= speed * dt;
      if (spawnGap <= 0) {
        spawnRow(spawnD);
        spawnGap = 800.0 + random.nextDouble() * 400.0;
      }

      // อุกกาบาตตกสุ่ม 2-3 ลูก
      meteorTimer -= dt;
      if (meteorTimer <= 0) {
        spawnMeteors();
        meteorTimer = 5.0 + random.nextDouble() * 3.0;
      }

      for (final GameObject obj in objects) {
        obj.d -= speed * dt;
        if (obj.type == ObjectType.meteor) {
          if (!obj.landed) {
            obj.h -= obj.vFall * dt;
            if (obj.h <= 0) {
              obj.h = 0;
              obj.landed = true;
              obj.impactT = 0.35;
            }
          } else if (obj.impactT > 0) {
            obj.impactT = math.max(0.0, obj.impactT - dt).toDouble();
          }
        }
      }

      checkCollisions();

      for (final Pop p in pops) {
        p.life -= dt;
      }
      pops.removeWhere((Pop p) => p.life <= 0);
      objects.removeWhere((GameObject o) => o.removed || o.d < -250);
    });
  }

  void updateJump(double dt) {
    double targetStretch = 0;

    if (jumping) {
      final double g = velocityY > 0 ? gravityUp : gravityDown;
      jumpY += velocityY * dt - 0.5 * g * dt * dt;
      velocityY -= g * dt;

      if (jumpY <= 0 && velocityY <= 0) {
        jumpY = 0;
        velocityY = 0;
        jumping = false;
        jumpCount = 0;
        flipProgress = 1.0;
        stretch = -0.14;
        if (rollQueued) {
          rollQueued = false;
          startRoll();
        }
      } else {
        targetStretch =
            (velocityY / jumpVelocity * 0.1).clamp(-0.06, 0.1).toDouble();
      }
    }

    if (flipProgress < 1.0) {
      flipProgress = math.min(1.0, flipProgress + dt / flipDuration);
    }

    // ม้วนตัว: ถ้ากดค้างอยู่ จะม้วนต่อเนื่อง ปล่อยแล้วค่อยนับเวลาถอยหลัง
    if (rolling) {
      if (!rollHeld) rollTimer -= dt;
      if (rollTimer <= 0) rolling = false;
    }

    // แอนิเมชันนุ่มๆ
    runPhase += dt * (9.0 + speed / 110.0);
    final double airTarget = (jumping || jumpY > 0.5) ? 1.0 : 0.0;
    airBlend += (airTarget - airBlend) * (1.0 - math.exp(-16.0 * dt));
    rollBlend +=
        ((rolling ? 1.0 : 0.0) - rollBlend) * (1.0 - math.exp(-20.0 * dt));
    if (rollBlend > 0.01) rollAngle += dt * (14.0 + speed / 100.0);

    final double targetTilt =
        ((targetLane - laneX) * 0.35).clamp(-0.3, 0.3).toDouble();
    final double k = 1.0 - math.exp(-14.0 * dt);
    dinoTilt += (targetTilt - dinoTilt) * k;
    stretch += (targetStretch - stretch) * k;
  }

  // -------------------------------------------------------------- spawning

  void spawnRow(double d) {
    const List<int> lanes = [-1, 0, 1];

    // แถวเนื้อล้วน
    if (random.nextDouble() < 0.25) {
      final int lane = lanes[random.nextInt(3)];
      if (random.nextBool()) {
        meatLine(lane, d, 6, 105);
      } else {
        meatArc(lane, d);
      }
      return;
    }

    // เลนปลอดภัยต้องอยู่ติดกับเลนปลอดภัยแถวก่อนหน้า
    final List<int> candidates =
        lanes.where((int l) => (l - lastSafe).abs() <= 1).toList();
    final int safe = candidates[random.nextInt(candidates.length)];
    lastSafe = safe;

    // โครงกระดูกในเลนอื่น (ม้วนตัวลอด หรือ กระโดด 2 ครั้ง)
    for (final int l in lanes) {
      if (l == safe) continue;
      if (random.nextDouble() < 0.8) {
        objects.add(GameObject(ObjectType.skeleton, l, d,
            variant: random.nextInt(2)));
      }
    }

    final double r = random.nextDouble();
    if (r < 0.25) {
      // เนื้อลอยเป็นโค้งให้โดดเก็บ
      meatArc(safe, d);
    } else if (r < 0.45) {
      // โครงกระดูก + เนื้อใต้โครง ต้องม้วนตัวลอดเก็บ
      objects.add(
          GameObject(ObjectType.skeleton, safe, d, variant: random.nextInt(2)));
      for (int i = 0; i < 5; i++) {
        objects.add(
            GameObject(ObjectType.meat, safe, d - 100 + i * 50.0, h: 22));
      }
    } else if (r < 0.9) {
      meatLine(safe, d - 150, 5, 100);
    }
  }

  void meatLine(int lane, double d0, int count, double gap) {
    for (int i = 0; i < count; i++) {
      objects.add(GameObject(ObjectType.meat, lane, d0 + i * gap, h: 35));
    }
  }

  void meatArc(int lane, double d) {
    const List<double> heights = [40, 95, 125, 95, 40];
    for (int i = 0; i < heights.length; i++) {
      objects.add(GameObject(ObjectType.meat, lane, d + (i - 2) * 75.0,
          h: heights[i]));
    }
  }

  void spawnMeteors() {
    final int count = 2 + random.nextInt(2); // 2 หรือ 3 ลูก
    final List<int> lanes = [-1, 0, 1]..shuffle(random);
    final double baseD = 1500.0 + random.nextDouble() * 500.0;
    for (int i = 0; i < count; i++) {
      objects.add(GameObject(
        ObjectType.meteor,
        lanes[i],
        baseD + i * (320.0 + random.nextDouble() * 120.0),
        h: 1100,
        vFall: 650.0 + random.nextDouble() * 200.0,
      ));
    }
  }

  // ------------------------------------------------------------ collisions

  void checkCollisions() {
    final double pBottom = jumpY;
    final double pTop = jumpY + (rolling ? 34.0 : 70.0);

    for (final GameObject obj in objects) {
      if (obj.removed || obj.hit) continue;
      if (obj.d.abs() > obj.len / 2 + 25) continue;

      final bool isMeat = obj.type == ObjectType.meat;
      final double dx = (obj.lane - laneX).abs();
      if (dx >= (isMeat ? 0.5 : 0.6)) continue;
      if (pTop <= obj.bottom || pBottom >= obj.top) continue;

      if (isMeat) {
        obj.removed = true;
        meatCollected++;
        totalMeat++; // ค่าเงินสะสม
        pops.add(Pop(laneX, jumpY + 80));
      } else {
        if (invuln > 0) continue;
        obj.hit = true;
        lives--;
        damageFlash = 0.25;
        invuln = 1.3;
        if (lives <= 0) {
          lives = 0;
          running = false;
          gameOver = true;
          stopBGM();
          rollHeld = false;
          bestScore = math.max(bestScore, score);
          break;
        }
      }
    }
  }

  // --------------------------------------------------------------- actions

  void resetDinoMotion() {
    jumping = false;
    rolling = false;
    rollQueued = false;
    rollHeld = false;
    rollTimer = 0;
    jumpY = 0;
    velocityY = 0;
    jumpCount = 0;
    flipProgress = 1.0;
    dinoTilt = 0;
    stretch = 0;
    targetLane = 0;
    laneX = 0;
    lastSafe = 0;
    runPhase = 0;
    airBlend = 0;
    rollBlend = 0;
    rollAngle = 0;
  }

  void goToStore() {
    setState(() => screen = AppScreen.skins);
  }

  void goToCredits() {
    setState(() => screen = AppScreen.credits);
  }

  void goToPlatformSelect() {
    setState(() => screen = AppScreen.platform);
  }

  void selectPlatform(GamePlatform p) {
    platform = p;
    startGame();
  }

  void startGame() {
    startBGM();
    setState(() {
      screen = AppScreen.game;
      running = false;
      gameOver = false;
      paused = false;
      resetDinoMotion();
      score = 0;
      meatCollected = 0; // totalMeat ไม่รีเซ็ต
      lives = 3;
      elapsed = 0;
      dist = 0;
      speed = baseSpeed;
      speedLevel = 0;
      speedUpTimer = 0;
      damageFlash = 0;
      invuln = 0;
      meteorTimer = 6;
      objects.clear();
      pops.clear();
      // เติมแถวแรกๆ เพื่อไม่ต้องรอนาน
      spawnRow(1100);
      spawnRow(1800);
      spawnRow(2500);
      spawnGap = 450;
    });
  }

  void returnHome() {
    stopBGM();
    setState(() {
      screen = AppScreen.home;
      running = false;
      gameOver = false;
      paused = false;
      resetDinoMotion();
      objects.clear();
      pops.clear();
    });
  }

  void togglePause() {
    if (screen != AppScreen.game || gameOver) return;
    setState(() {
      paused = !paused;
      if (paused) {
      bgmPlayer.pause();
    } else {
      bgmPlayer.resume();
    }
      rollHeld = false;
    });
  }

  // ------------------------------------------------------------ skin store

  void showMsg(String text) {
    final ScaffoldMessengerState m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(milliseconds: 1800),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void buySkin(int id) {
    final SkinDef s = skins[id];
    if (ownedSkins.contains(id)) return;
    if (totalMeat < s.price) {
      showMsg('เนื้อไม่พอ! ต้องการอีก ${s.price - totalMeat} ชิ้น');
      return;
    }
    setState(() {
      totalMeat -= s.price;
      ownedSkins.add(id);
    });
    showMsg('ซื้อ ${s.name} สำเร็จ! คุณเป็นเจ้าของแล้ว');
  }

  void equipSkin(int id) {
    if (!ownedSkins.contains(id)) return;
    setState(() => selectedSkin = id);
  }

  // ----------------------------------------------------------- input

  /// true = การกดนี้ถูกใช้ไปแล้ว (เริ่มวิ่ง หรืออยู่นอกเกม)
  bool beginRunIfWaiting() {
    if (screen != AppScreen.game || gameOver || paused) return true;
    if (!running) {
      running = true;
      return true;
    }
    return false;
  }

  void moveLane(int dir) {
    setState(() {
      if (beginRunIfWaiting()) return;
      targetLane = (targetLane + dir).clamp(-1, 1);
    });
  }

  void pressJump() {
    setState(() {
      if (beginRunIfWaiting()) return;
      if (jumpCount >= maxJumps) return;
      rolling = false;
      rollQueued = false;
      jumpCount++;
      jumping = true;
      if (jumpCount == 1) {
        velocityY = jumpVelocity;
      } else {
        velocityY = doubleJumpVelocity;
        flipProgress = 0.0;
        stretch = 0.12;
      }
    });
  }

  void startRoll() {
    rolling = true;
    rollTimer = rollMinDuration;
  }

  void pressRoll() {
    setState(() {
      rollHeld = true;
      if (beginRunIfWaiting()) return;
      if (jumping) {
        // กดลงกลางอากาศ = ดิ่งลงเร็ว แล้วกลิ้งต่อทันทีที่ถึงพื้น
        velocityY = math.min(velocityY, -950.0).toDouble();
        rollQueued = true;
      } else {
        startRoll();
      }
    });
  }

  /// ปล่อยปุ่มม้วนตัว
  void releaseRoll() {
    rollHeld = false;
  }

  void handlePointerDown(PointerDownEvent e) {
    if (uiPointers.contains(e.pointer)) return;
    swipeAcc[e.pointer] = Offset.zero;
  }

  /// มือถือ: ใช้ปุ่มลูกศรบนจอ (ไม่ใช้การปัดแล้ว)
  void handlePointerMove(PointerMoveEvent e) {
    final Offset? acc0 = swipeAcc[e.pointer];
    if (acc0 == null) return;
    // มือถือใช้ปุ่มลูกศรบนจอแทนการปัด จึงไม่ต้องทำอะไรที่นี่
    return;
  }

  void handlePointerEnd(PointerEvent e) {
    swipeAcc.remove(e.pointer);
    uiPointers.remove(e.pointer);
  }

  KeyEventResult handleKey(FocusNode node, KeyEvent event) {
    if (screen != AppScreen.game) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = event.logicalKey;

    if (event is KeyUpEvent) {
      if (platform == GamePlatform.pc &&
          (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS)) {
        releaseRoll();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyP) {
      togglePause();
      return KeyEventResult.handled;
    }
    if (platform != GamePlatform.pc) return KeyEventResult.ignored;

    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      moveLane(-1);
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.keyD) {
      moveLane(1);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW ||
        k == LogicalKeyboardKey.space) {
      pressJump();
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyS) {
      pressRoll();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final EdgeInsets pad = mq.padding;
    final double uu = math.min(mq.size.height / 600.0, mq.size.width / 340.0);
    final double fs = uu.clamp(0.8, 1.4).toDouble();
    final bool inGame = screen == AppScreen.game;
    final bool menu = !inGame;

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: handleKey,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: handlePointerDown,
          onPointerMove: handlePointerMove,
          onPointerUp: handlePointerEnd,
          onPointerCancel: handlePointerEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: DinoPainter(
                  menu: menu,
                  erupt: true,
                  running: running,
                  worldTime: worldTime,
                  dist: dist,
                  elapsed: elapsed,
                  score: score,
                  lives: lives,
                  meat: totalMeat,
                  speed: speed,
                  laneX: laneX,
                  jumpY: jumpY,
                  damageFlash: damageFlash,
                  invuln: invuln,
                  dinoTilt: dinoTilt,
                  stretch: stretch,
                  flipProgress: flipProgress,
                  objects: objects,
                  pops: pops,
                  topInset: pad.top,
                  skin: skins[selectedSkin],
                  runPhase: runPhase,
                  airBlend: airBlend,
                  rollBlend: rollBlend,
                  rollAngle: rollAngle,
                  speedUpTimer: speedUpTimer,
                  level: speedLevel,
                ),
              ),
              if (screen == AppScreen.home) homeOverlay(),
              if (screen == AppScreen.skins) skinOverlay(pad),
              if (screen == AppScreen.platform) platformOverlay(),
              if (screen == AppScreen.credits) creditsOverlay(pad),
              if (inGame && !gameOver) ...[
                if (platform == GamePlatform.mobile) mobileControls(pad),
                if (!running && !paused) readyOverlay(pad),
                Positioned(
                  left: 14,
                  top: pad.top + 10 + 24.0 * fs * 1.35 + 6,
                  child: pauseButton(),
                ),
              ],
              if (inGame && paused && !gameOver) pauseOverlay(),
              if (inGame && gameOver) gameOverOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- overlays

  static const List<Shadow> textShadow = [
    Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(2, 3)),
  ];

  Widget homeOverlay() {
    final EdgeInsets pad = MediaQuery.of(context).padding;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('JURASSIC',
                    style: TextStyle(
                      fontSize: 43,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      color: Color(0xFFFFD45C),
                      shadows: [
                        Shadow(
                            color: Colors.black87,
                            blurRadius: 8,
                            offset: Offset(3, 4))
                      ],
                    )),
                const Text('DINO RUNNER',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white,
                      shadows: textShadow,
                    )),
                const SizedBox(height: 10),
                const Text('วันสิ้นโลกของเหล่าไดโนเสาร์',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB38A),
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    )),
                const SizedBox(height: 16),
                meatBadge(totalMeat),
                const SizedBox(height: 22),
                // PLAY -> เลือกแพลตฟอร์ม
                actionButton('PLAY', goToPlatformSelect),
                const SizedBox(height: 12),
                // STORE -> ร้านค้า (ซื้อ/เลือกสกิน)
                actionButton('STORE', goToStore, secondary: true),
              ],
            ),
          ),
        ),
        // ปุ่มผู้จัดทำ ขวาล่าง
        Positioned(
          right: 14 + pad.right,
          bottom: 14 + pad.bottom,
          child: creditsButton(),
        ),
      ],
    );
  }

  Widget creditsButton() {
    return Material(
      color: const Color(0xCC2B1A14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFFD45C), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: goToCredits,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_rounded, color: Color(0xFFFFD45C), size: 22),
              SizedBox(width: 6),
              Text('ผู้จัดทำ',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  /// หน้าผู้จัดทำ (ข้อมูลมาจาก developers ด้านบนของไฟล์)
  Widget creditsOverlay(EdgeInsets pad) {
    return Container(
      color: const Color(0xF0140A08),
      child: Column(
        children: [
          SizedBox(height: pad.top + 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFFFFD45C), size: 28),
                  onPressed: () => setState(() => screen = AppScreen.home),
                ),
                const Expanded(
                  child: Text('ผู้จัดทำ',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD45C),
                        shadows: textShadow,
                      )),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(14, 12, 14, pad.bottom + 16),
              itemCount: developers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, int i) => developerCard(developers[i], i + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget developerCard(Developer d, int no) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1A14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD45C), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF3A2620),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                d.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    size: 60,
                    color: Colors.white38),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ผู้จัดทำคนที่ $no',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB38A))),
                const SizedBox(height: 8),
                infoLine('ชื่อ', d.firstName),
                infoLine('นามสกุล', d.lastName),
                infoLine('รหัสนักศึกษา', d.studentId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '$label: ',
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
        TextSpan(
            text: value,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
      ])),
    );
  }

  /// หน้าเลือก/ซื้อสกิน (ก่อนกด Play) เนื้อสะสมอยู่ขวาบน
  Widget skinOverlay(EdgeInsets pad) {
    return Container(
      color: const Color(0xE6140A08),
      child: Column(
        children: [
          SizedBox(height: pad.top + 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFFFFD45C), size: 28),
                  onPressed: () => setState(() => screen = AppScreen.home),
                ),
                const Expanded(
                  child: Text('STORE  ร้านค้า',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD45C),
                        shadows: textShadow,
                      )),
                ),
                meatBadge(totalMeat),
                const SizedBox(width: 6),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              itemCount: skins.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, int i) => skinCard(skins[i]),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: pad.bottom + 12, top: 6),
            child: actionButton('กลับหน้าแรก', () => setState(() => screen = AppScreen.home)),
          ),
        ],
      ),
    );
  }

  Widget skinCard(SkinDef s) {
    final bool owned = ownedSkins.contains(s.id);
    final bool equipped = selectedSkin == s.id;
    final Color border = equipped
        ? const Color(0xFF7CFF8A)
        : (s.special ? const Color(0xFFFF8AE0) : const Color(0xFFFFD45C));

    Widget action;
    if (!owned) {
      action = SizedBox(
        height: 38,
        child: ElevatedButton(
          onPressed: () => buySkin(s.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC847),
            foregroundColor: const Color(0xFF2B1A14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ซื้อ ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CustomPaint(painter: MeatIconPainter())),
              Text(' ${s.price}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    } else {
      action = SizedBox(
        height: 38,
        child: ElevatedButton(
          onPressed: equipped ? null : () => equipSkin(s.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3DBB5A),
            foregroundColor: const Color(0xFF10260F),
            disabledBackgroundColor: const Color(0xFF3A3A3A),
            disabledForegroundColor: Colors.white70,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(equipped ? 'กำลังใช้งาน' : 'ใช้งาน',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1A14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: equipped ? 3 : 2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 112,
            child: CustomPaint(painter: SkinPreviewPainter(s, worldTime)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(s.desc,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 6),
                if (owned)
                  const Text('✔ คุณเป็นเจ้าของแล้ว',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7CFF8A)))
                else
                  Text(s.special ? 'สกินพิเศษ มีเอฟเฟกต์เคลื่อนไหว' : 'สกินแฟนตาซี',
                      style: TextStyle(
                          fontSize: 13,
                          color: s.special
                              ? const Color(0xFFFF8AE0)
                              : const Color(0xFFFFB38A))),
                const SizedBox(height: 8),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget platformOverlay() {
    return Container(
      color: const Color(0xAA000000),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('เลือกแพลตฟอร์ม',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD45C),
                    shadows: textShadow,
                  )),
              const SizedBox(height: 20),
              platformCard(
                Icons.smartphone_rounded,
                'มือถือ',
                'ซ้ายล่าง: ↑ กระโดด (กด 2 ครั้ง = กระโดด 2 ขั้น) • ↓ หมุนตัว (กดค้างได้)\nขวาล่าง: ← → เปลี่ยนเลนครั้งละ 1 เลน',
                () => selectPlatform(GamePlatform.mobile),
              ),
              const SizedBox(height: 14),
              platformCard(
                Icons.keyboard_rounded,
                'PC',
                'ใช้ปุ่มลูกศรบนแป้นพิมพ์\n← → เปลี่ยนเลน • ↑ กระโดด • ↓ ม้วนตัว (กดค้างได้)',
                () => selectPlatform(GamePlatform.pc),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => setState(() => screen = AppScreen.home),
                child: const Text('ย้อนกลับ',
                    style: TextStyle(fontSize: 16, color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget platformCard(
      IconData icon, String label, String desc, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF2B1A14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFFD45C), width: 2.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 44, color: const Color(0xFFFFD45C)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(desc,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget mobileControls(EdgeInsets pad) {
    final double bottom = pad.bottom + 16;
    return Stack(
      children: [
        // ซ้ายล่าง: ลูกศรขึ้น (อยู่บน) / ลูกศรลง (อยู่ใต้ปุ่มขึ้น)
        Positioned(
          left: 18 + pad.left,
          bottom: bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // กด 1 ครั้ง = กระโดด, กด 2 ครั้งติดกัน = กระโดด 2 ขั้น
              controlButton(Icons.keyboard_arrow_up_rounded, onDown: pressJump),
              const SizedBox(height: 12),
              // กดค้างเพื่อหมุนตัวต่อเนื่อง
              controlButton(Icons.keyboard_arrow_down_rounded,
                  onDown: pressRoll, onUp: releaseRoll, active: rolling),
            ],
          ),
        ),
        // ขวาล่าง: ลูกศรซ้าย (ซ้าย) / ลูกศรขวา (ขวา) กด 1 ครั้ง = เปลี่ยน 1 เลน
        Positioned(
          right: 18 + pad.right,
          bottom: bottom,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              controlButton(Icons.keyboard_arrow_left_rounded,
                  onDown: () => moveLane(-1)),
              const SizedBox(width: 12),
              controlButton(Icons.keyboard_arrow_right_rounded,
                  onDown: () => moveLane(1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget readyOverlay(EdgeInsets pad) {
    final bool mobile = platform == GamePlatform.mobile;
    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: Align(
            alignment: Alignment(0, -0.45),
            child: Text('READY?',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Color(0xFFFFD45C),
                  shadows: textShadow,
                )),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: pad.bottom + (mobile ? 120 : 40),
          child: IgnorePointer(
            child: Center(
              child: Text(
                mobile
                    ? 'กดปุ่มลูกศรบนหน้าจอเพื่อเริ่มวิ่ง'
                    : 'กดปุ่มลูกศรบนแป้นพิมพ์เพื่อเริ่มวิ่ง',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget pauseButton() {
    return GestureDetector(
      onTapDown: (_) => togglePause(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xCC2B1A14),
          border: Border.all(color: const Color(0xFFFFD45C), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.pause_rounded,
            size: 28, color: Color(0xFFFFD45C)),
      ),
    );
  }

  Widget panel({required List<Widget> children}) {
    return Container(
      color: const Color(0xB9000000),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF2B1A14),
            border: Border.all(color: const Color(0xFFFFD45C), width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  Widget pauseOverlay() {
    return panel(children: [
      const Text('PAUSED',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD45C),
          )),
      const SizedBox(height: 18),
      actionButton('เล่นต่อ', togglePause),
      const SizedBox(height: 10),
      actionButton('เริ่มเกมใหม่', startGame, secondary: true),
      const SizedBox(height: 10),
      actionButton('ออก', returnHome, secondary: true),
    ]);
  }

  Widget gameOverOverlay() {
    return panel(children: [
      const Text('GAME OVER',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD45C),
          )),
      const SizedBox(height: 12),
      Text('ระยะทาง: $score เมตร',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('คะแนน: $score',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('เนื้อที่เก็บได้: $meatCollected ชิ้น',
          style: const TextStyle(fontSize: 17, color: Colors.white70)),
      Text('เนื้อสะสมทั้งหมด: $totalMeat ชิ้น',
          style: const TextStyle(fontSize: 17, color: Color(0xFFFFE16A))),
      Text('เวลา: ${elapsed.floor()} วินาที',
          style: const TextStyle(fontSize: 16, color: Colors.white70)),
      Text('คะแนนสูงสุด: $bestScore',
          style: const TextStyle(fontSize: 16, color: Colors.white70)),
      const SizedBox(height: 20),
      actionButton('เริ่มเกมใหม่', startGame),
      const SizedBox(height: 10),
      actionButton('ออก', returnHome, secondary: true),
    ]);
  }

  Widget meatBadge(int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD45C), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 26,
              height: 26,
              child: CustomPaint(painter: MeatIconPainter())),
          const SizedBox(width: 8),
          Text('$n',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE16A))),
        ],
      ),
    );
  }

  Widget actionButton(String label, VoidCallback onPressed,
      {bool secondary = false}) {
    return SizedBox(
      width: 205,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              secondary ? const Color(0xFF5A4036) : const Color(0xFFFFC847),
          foregroundColor: secondary ? Colors.white : const Color(0xFF2B1A14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      ),
    );
  }

  /// ปุ่มลูกศรบนมือถือ ใช้ Listener เพื่อรองรับการกดค้าง และหลายนิ้วพร้อมกัน
  Widget controlButton(IconData icon,
      {required VoidCallback onDown, VoidCallback? onUp, bool active = false}) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent e) {
        uiPointers.add(e.pointer);
        onDown();
      },
      onPointerUp: (_) => onUp?.call(),
      onPointerCancel: (_) => onUp?.call(),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: active ? const Color(0xEE6B4424) : const Color(0xCC2B1A14),
          border: Border.all(
              color: active ? Colors.white : const Color(0xFFFFD45C),
              width: 2.5),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Icon(icon, size: 56, color: const Color(0xFFFFD45C)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter (pseudo-3D มองจากด้านหลังผู้เล่น)
// ---------------------------------------------------------------------------

class _Item {
  _Item(this.d, this.draw);
  final double d;
  final VoidCallback draw;
}

class DinoPainter extends CustomPainter {
  DinoPainter({
    required this.menu,
    required this.erupt,
    required this.running,
    required this.worldTime,
    required this.dist,
    required this.elapsed,
    required this.score,
    required this.lives,
    required this.meat,
    required this.speed,
    required this.laneX,
    required this.jumpY,
    required this.damageFlash,
    required this.invuln,
    required this.dinoTilt,
    required this.stretch,
    required this.flipProgress,
    required this.objects,
    required this.pops,
    required this.topInset,
    required this.skin,
    required this.runPhase,
    required this.airBlend,
    required this.rollBlend,
    required this.rollAngle,
    required this.speedUpTimer,
    required this.level,
  });

  final bool menu, erupt, running;
  final double worldTime, dist, elapsed, speed, laneX, jumpY;
  final double damageFlash, invuln, dinoTilt, stretch, flipProgress, topInset;
  final double runPhase, airBlend, rollBlend, rollAngle, speedUpTimer;
  final int score, lives, meat, level;
  final SkinDef skin;
  final List<GameObject> objects;
  final List<Pop> pops;

  static const double focal = 700;
  static const double farD = 6000;
  static const double nearD = -320;

  late double w, h, u, laneW, horizonY, playerY;

  double sc(double d) => focal / (focal + d);

  Offset gp(double lane, double d) {
    final double s = sc(d);
    return Offset(
      w / 2 + lane * laneW * s,
      horizonY + (playerY - horizonY) * s,
    );
  }

  static double easeOutCubic(double t) {
    final double v = 1.0 - t;
    return 1.0 - v * v * v;
  }

  static int al(double v) => v.clamp(0.0, 255.0).round();

  Path poly(List<Offset> pts) {
    final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final Offset o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  Path strip(double l, double d0, double d1) => poly([
        gp(-l, d0),
        gp(l, d0),
        gp(l, d1),
        gp(-l, d1),
      ]);

  @override
  void paint(Canvas canvas, Size size) {
    w = size.width;
    h = size.height;
    u = math.min(h / 600.0, w / 340.0);
    laneW = 105.0 * u;
    horizonY = h * 0.30;
    playerY = h * 0.78;

    canvas.save();

    // จอสั่นตอนภูเขาไฟเริ่มระเบิด (ตอนวิ่งสั่นเบากว่า เพื่อไม่ให้รบกวนการเล่น)
    final double ct = worldTime % 3.0;
    if (erupt && ct < 0.35) {
      final double k = (1.0 - ct / 0.35) * (running ? 0.4 : 1.0);
      canvas.translate(
          math.sin(worldTime * 90) * 3 * u * k,
          math.cos(worldTime * 70) * 3 * u * k);
    }

    drawSkyAndGround(canvas);
    drawDirt(canvas);

    final List<_Item> items = [];

    // ของตกแต่งสองข้างทาง (ธีมวันสิ้นโลก + ยุคไดโนเสาร์)
    // 0 ต้นไม้ไหม้ 1 หิน 2 กระดูก 3 บ่อลาวา 4 เสาซากปรักหักพัง
    // 5 ซี่โครงยักษ์ 6 กองไฟ 7 เสาปักกะโหลก
    // 8 ต้นปาล์มยุคดึกดำบรรพ์ 9 เฟิร์นยักษ์ 10 ปรง (cycad)
    // 11 รังไข่ไดโนเสาร์ 12 ไดโนเสาร์คอยาวยืนอยู่ 13 สเตโกซอรัสยืนอยู่
    const List<int> decorTable = [
      8, 0, 10, 12, 1, 9, 11, 4, 8, 13, 2, 10, 5, 9, 6, 11, 3, 8, 7, 12
    ];
    final int baseIdx = (dist / 260.0).floor();
    final double off = dist % 260.0;
    for (int k = 0; k < 16; k++) {
      final double d = k * 260.0 - off;
      if (d < -180) continue;
      final int idx = baseIdx + k;
      for (int side = -1; side <= 1; side += 2) {
        final int hv = (((idx * 31 + (side > 0 ? 17 : 3)) % 20) + 20) % 20;
        final int variant = decorTable[hv];
        final bool bigDino = variant == 12 || variant == 13;
        final double lane = side *
            (bigDino
                ? 3.0 + (hv % 2) * 0.5
                : (variant == 11 ? 1.9 + (hv % 3) * 0.3 : 2.2 + (hv % 3) * 0.6));
        items.add(_Item(d, () => drawDecor(canvas, lane, d, variant, idx)));
      }
    }

    // ของตกแต่งเล็กๆ เติมช่องว่างริมทาง (เฟิร์น ไข่ ปรง หิน กระดูก)
    const List<int> fillTable = [9, 11, 9, 10, 9, 1, 2, 9];
    for (int k = 0; k < 16; k++) {
      final double d = k * 260.0 + 130.0 - off;
      if (d < -180) continue;
      final int idx = baseIdx + k;
      for (int side = -1; side <= 1; side += 2) {
        final int hv2 = (((idx * 17 + (side > 0 ? 5 : 11)) % 8) + 8) % 8;
        final int variant = fillTable[hv2];
        final double lane = side * (1.85 + (hv2 % 3) * 0.35);
        items.add(
            _Item(d, () => drawDecor(canvas, lane, d, variant, idx + 500)));
      }
    }

    // วัตถุบนแทร็ก
    for (final GameObject obj in objects) {
      if (obj.d > 3200 || obj.d < -250) continue;
      items.add(_Item(obj.d, () => drawObject(canvas, obj)));
    }

    // ผู้เล่นอยู่ที่ d = 0
    items.add(_Item(0, () => drawPlayer(canvas)));

    items.sort((_Item a, _Item b) => b.d.compareTo(a.d));
    for (final _Item it in items) {
      it.draw();
    }

    drawFog(canvas);
    drawEmbers(canvas);

    // ตัวเลข +1
    for (final Pop p in pops) {
      final double a = (p.life / 0.7).clamp(0.0, 1.0).toDouble();
      final double x = w / 2 + p.lane * laneW;
      final double y = playerY - (p.y + (0.7 - p.life) * 70.0) * u;
      drawText(canvas, '+1', x, y, 18.0 * u.clamp(0.8, 1.4).toDouble(),
          Color.fromARGB((255 * a).round(), 255, 225, 106),
          center: true);
    }

    if (!menu) drawHud(canvas);

    canvas.restore();

    if (damageFlash > 0) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0x44FF0000));
    }
  }

  // ------------------------------------------------------------ background

  void drawSkyAndGround(Canvas canvas) {
    final Rect skyRect = Rect.fromLTWH(0, 0, w, horizonY + 1);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A0E1E), Color(0xFF9E2F22), Color(0xFFFF8A3D)],
        ).createShader(skyRect),
    );

    // ดวงอาทิตย์สีเลือด
    final Offset sun = Offset(w * 0.2, horizonY * 0.5);
    glow(canvas, sun, 75 * u, 90);
    canvas.drawCircle(sun, 30 * u, Paint()..color = const Color(0xFFFF5A36));

    // เมฆควันสีเข้มลอยช้าๆ
    final double drift = dist * 0.03 + worldTime * 4;
    for (int i = 0; i < 3; i++) {
      final double baseX = [0.12, 0.45, 0.8][i] * w;
      final double x = ((baseX - drift) % (w + 140.0)) - 70.0;
      drawCloud(canvas, x, horizonY * [0.35, 0.6, 0.3][i], u);
    }

    drawSkyStreaks(canvas);
    drawVolcano(canvas);

    final Rect groundRect = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    canvas.drawRect(
      groundRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5535), Color(0xFF3C2418)],
        ).createShader(groundRect),
    );
  }

  /// ดาวหาง/อุกกาบาตพาดท้องฟ้า (วันสิ้นโลก)
  void drawSkyStreaks(Canvas canvas) {
    for (int i = 0; i < 3; i++) {
      final double cyc = worldTime * 0.7 + i * 1.9;
      final double tt = cyc % 4.0;
      if (tt > 1.0) continue;
      final int n = (cyc / 4.0).floor();
      final double sx = w * (0.1 + 0.33 * i) + hash01(n, i + 50) * w * 0.2;
      final Offset head = Offset(sx + tt * w * 0.30, tt * horizonY * 0.85 + 6);
      final Offset tail = head - Offset(w * 0.10, horizonY * 0.28);
      final double a = math.sin(tt * math.pi);
      canvas.drawLine(
          tail,
          head,
          Paint()
            ..strokeWidth = math.max(1.5, 2.5 * u)
            ..strokeCap = StrokeCap.round
            ..color = Color.fromARGB(al(230 * a), 255, 190, 100));
      canvas.drawCircle(head, 3 * u,
          Paint()..color = Color.fromARGB(al(255 * a), 255, 130, 60));
    }
  }

  void glow(Canvas canvas, Offset c, double r, int a) {
    final int aa = a.clamp(0, 255).toInt();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          Color.fromARGB(aa, 255, 150, 60),
          const Color(0x00FF963C),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void drawCloud(Canvas canvas, double x, double y, double k) {
    final Paint p = Paint()..color = const Color(0xAA3B2A2F);
    canvas.drawCircle(Offset(x, y), 19 * k, p);
    canvas.drawCircle(Offset(x + 22 * k, y - 10 * k), 24 * k, p);
    canvas.drawCircle(Offset(x + 47 * k, y), 18 * k, p);
    canvas.drawRect(Rect.fromLTWH(x, y - 1 * k, 47 * k, 19 * k), p);
  }

  /// ภูเขาไฟ: ระเบิดทุก 3 วินาที ทั้งในเมนูและระหว่างเล่น
  void drawVolcano(Canvas canvas) {
    final Path mountain = Path()
      ..moveTo(w * 0.10, horizonY)
      ..lineTo(w * 0.32, horizonY - h * 0.13)
      ..lineTo(w * 0.40, horizonY - h * 0.08)
      ..lineTo(w * 0.53, horizonY - h * 0.18)
      ..lineTo(w * 0.88, horizonY)
      ..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFF3A2724));
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.53, horizonY - h * 0.18)
          ..lineTo(w * 0.88, horizonY)
          ..lineTo(w * 0.62, horizonY)
          ..close(),
        Paint()..color = const Color(0x33000000));

    final Path lava = Path()
      ..moveTo(w * 0.47, horizonY - h * 0.14)
      ..lineTo(w * 0.53, horizonY - h * 0.18)
      ..lineTo(w * 0.585, horizonY - h * 0.12)
      ..lineTo(w * 0.54, horizonY - h * 0.09)
      ..lineTo(w * 0.50, horizonY - h * 0.115)
      ..close();
    canvas.drawPath(lava, Paint()..color = const Color(0xFFFF6A35));

    // ลาวาไหลลงเขา
    final Paint stream = Paint()
      ..color = const Color(0xFFFF6A35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 2.5 * u)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.52, horizonY - h * 0.15)
          ..lineTo(w * 0.50, horizonY - h * 0.10)
          ..lineTo(w * 0.53, horizonY - h * 0.05)
          ..lineTo(w * 0.51, horizonY),
        stream);
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.56, horizonY - h * 0.13)
          ..lineTo(w * 0.60, horizonY - h * 0.07)
          ..lineTo(w * 0.58, horizonY),
        stream);

    final Offset crater = Offset(w * 0.53, horizonY - h * 0.18);
    final double t = worldTime % 3.0;

    if (!erupt) {
      glow(canvas, crater, 55 * u, (50 + 25 * math.sin(worldTime * 3)).round());
      return;
    }

    // แสงวาบทั้งท้องฟ้า
    if (t < 0.45) {
      final double f = 1.0 - t / 0.45;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, horizonY),
          Paint()..color = Color.fromARGB(al(70 * f), 255, 150, 70));
    }

    final double burst = math.max(0.0, 1.0 - t / 1.2);
    glow(canvas, crater, (60 + 80 * burst) * u, (90 + 120 * burst).round());

    // เสาลาวาพุ่งขึ้น
    if (t < 1.4) {
      final double k =
          easeOutCubic((t / 0.45).clamp(0.0, 1.0).toDouble()) * (1.0 - t / 1.4);
      final double fh = h * 0.2 * k;
      final double fw = 26 * u * (0.4 + k);
      canvas.drawPath(
          poly([
            Offset(crater.dx - fw, crater.dy + 4 * u),
            Offset(crater.dx - fw * 0.2, crater.dy - fh),
            Offset(crater.dx + fw * 0.2, crater.dy - fh),
            Offset(crater.dx + fw, crater.dy + 4 * u),
          ]),
          Paint()..color = const Color(0xCCFF7B35));
      canvas.drawPath(
          poly([
            Offset(crater.dx - fw * 0.5, crater.dy + 4 * u),
            Offset(crater.dx - fw * 0.1, crater.dy - fh * 0.8),
            Offset(crater.dx + fw * 0.1, crater.dy - fh * 0.8),
            Offset(crater.dx + fw * 0.5, crater.dy + 4 * u),
          ]),
          Paint()..color = const Color(0xDDFFC65A));
    }

    // ก้อนลาวาปลิวเป็นวิถีโค้ง
    for (int i = 0; i < 18; i++) {
      final double ang = -math.pi / 2 + (hash01(i, 1) - 0.5) * 1.7;
      final double sp = (300 + hash01(i, 2) * 380) * u;
      final double bx = crater.dx + math.cos(ang) * sp * t;
      final double by =
          crater.dy + math.sin(ang) * sp * t + 0.5 * 520 * u * t * t;
      if (by > horizonY - 2 * u) continue;
      final double r = (2.5 + hash01(i, 3) * 3.5) * u;
      final double fade = (1.0 - t / 2.8).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(Offset(bx, by), r,
          Paint()..color = Color.fromARGB(al(255 * fade), 255, 123, 53));
      canvas.drawCircle(Offset(bx, by), r * 0.5,
          Paint()..color = Color.fromARGB(al(255 * fade), 255, 210, 110));
    }

    // ควันเถ้าถ่านลอยขึ้น
    for (int j = 0; j < 8; j++) {
      final double tt = t - j * 0.1;
      if (tt < 0) continue;
      final double cx = crater.dx + (math.sin(j * 1.7) * 8 + tt * 14) * u;
      final double cy = crater.dy - (tt * 85 + j * 10) * u;
      final double r = (14 + tt * 16 + j * 2.5) * u;
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()..color = Color.fromARGB(al(150 * (1 - t / 3.0)), 48, 36, 38));
    }
  }

  /// พื้นดิน: ทางเดินดินสึก + รอยแตก ก้อนกรวด หญ้าแห้ง เลื่อนตามระยะ
  void drawDirt(Canvas canvas) {
    canvas.drawPath(
        strip(2.0, nearD, farD), Paint()..color = const Color(0x18FFD6A0));
    canvas.drawPath(
        strip(1.55, nearD, farD), Paint()..color = const Color(0x1AFFD6A0));

    const double bandLen = 200;
    final int baseIdx = (dist / bandLen).floor();
    final double off = dist % bandLen;
    final Paint shade = Paint()..color = const Color(0x12000000);

    for (int i = -2; i < 32; i++) {
      final int idx = baseIdx + i;
      final double d0 = i * bandLen - off;
      final double d1 = d0 + bandLen;

      if (idx.isEven && d1 > nearD && d0 < farD) {
        canvas.drawPath(
            strip(4.0, math.max(d0, nearD).toDouble(), d1), shade);
      }

      for (int m = 0; m < 4; m++) {
        final int id = idx * 4 + m;
        final double lane = (hash01(id, 5) - 0.5) * 7.0;
        final double dd = d0 + hash01(id, 6) * bandLen;
        if (dd < nearD || dd > farD) continue;
        final Offset p = gp(lane, dd);
        final double px = u * sc(dd);
        final double kind = hash01(id, 7);

        if (kind < 0.45) {
          // รอยแตกของดิน (บางรอยมีลาวาเรือง)
          final Path c = Path()
            ..moveTo(p.dx - 16 * px, p.dy)
            ..lineTo(p.dx - 5 * px, p.dy - 3 * px)
            ..lineTo(p.dx + 4 * px, p.dy + 1 * px)
            ..lineTo(p.dx + 17 * px, p.dy - 2 * px);
          canvas.drawPath(
              c,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = math.max(1.0, 2.2 * px)
                ..color = const Color(0xFF24150E));
          if (hash01(id, 8) > 0.55) {
            canvas.drawPath(
                c,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = math.max(0.8, 1.0 * px)
                  ..color = const Color(0xAAFF6A35));
          }
        } else if (kind < 0.8) {
          // ก้อนกรวด
          final double pw = (8 + hash01(id, 9) * 8) * px;
          canvas.drawOval(
              Rect.fromCenter(center: p, width: pw, height: pw * 0.5),
              Paint()..color = const Color(0xFF5A3C2B));
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(p.dx - pw * 0.1, p.dy - pw * 0.1),
                  width: pw * 0.5,
                  height: pw * 0.25),
              Paint()..color = const Color(0xFF7A5640));
        } else {
          // หญ้าแห้ง
          final Paint tuft = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, 1.5 * px)
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF6B4A2A);
          canvas.drawLine(p, Offset(p.dx - 5 * px, p.dy - 12 * px), tuft);
          canvas.drawLine(p, Offset(p.dx, p.dy - 15 * px), tuft);
          canvas.drawLine(p, Offset(p.dx + 5 * px, p.dy - 11 * px), tuft);
        }
      }
    }
  }

  void drawFog(Canvas canvas) {
    final Rect fog = Rect.fromLTWH(0, horizonY - 2, w, h * 0.16);
    canvas.drawRect(
      fog,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8A3D), Color(0x00FF8A3D)],
        ).createShader(fog),
    );
  }

  /// ประกายไฟ/เถ้าลอยขึ้นทั่วฉาก
  void drawEmbers(Canvas canvas) {
    for (int i = 0; i < 26; i++) {
      final double x = hash01(i, 1) * w + math.sin(worldTime * 0.8 + i) * 12 * u;
      final double rise = worldTime * (35 + hash01(i, 2) * 50) * u;
      final double y = h - ((rise + hash01(i, 3) * h) % h);
      final double r = (1.0 + hash01(i, 4) * 2.2) * u.clamp(0.8, 1.4).toDouble();
      final double a = 120 + 100 * math.sin(worldTime * 3 + i);
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = Color.fromARGB(al(a), 255, 162, 58));
    }
  }

  // ----------------------------------------------------------------- decor

  void drawDecor(Canvas canvas, double lane, double d, int variant, int idx) {
    final Offset p = gp(lane, d);
    final double px = u * sc(d);
    switch (variant) {
      case 0:
        drawDeadTree(canvas, p, px, idx);
        break;
      case 1:
        drawRocks(canvas, p, px);
        break;
      case 2:
        drawBones(canvas, p, px);
        break;
      case 3:
        drawLavaPool(canvas, p, px);
        break;
      case 4:
        drawRuin(canvas, p, px, idx);
        break;
      case 5:
        drawGiantRibs(canvas, p, px);
        break;
      case 6:
        drawFirePit(canvas, p, px, idx);
        break;
      case 8:
        drawPalm(canvas, p, px, idx);
        break;
      case 9:
        drawFern(canvas, p, px, idx);
        break;
      case 10:
        drawCycad(canvas, p, px, idx);
        break;
      case 11:
        drawEggNest(canvas, p, px, idx);
        break;
      case 12:
        drawBronto(canvas, p, px, idx, lane > 0 ? -1.0 : 1.0);
        break;
      case 13:
        drawStego(canvas, p, px, idx, lane > 0 ? -1.0 : 1.0);
        break;
      default:
        drawSkullPole(canvas, p, px, idx);
        break;
    }
  }

  // ----------------------------------------------- ธีมยุคไดโนเสาร์

  void groundShadow(Canvas canvas, Offset p, double w, double h) {
    canvas.drawOval(Rect.fromCenter(center: p, width: w, height: h),
        Paint()..color = const Color(0x33000000));
  }

  /// ต้นปาล์มยุคดึกดำบรรพ์ ใบแกว่งตามลม
  void drawPalm(Canvas canvas, Offset p, double px, int idx) {
    groundShadow(canvas, p, 70 * px, 10 * px);
    final double th = (120 + (idx % 3) * 20) * px;
    final double lean =
        ((idx % 2 == 0) ? 1.0 : -1.0) * (16 + (idx % 3) * 6) * px;
    final Offset top = Offset(p.dx + lean, p.dy - th);
    canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(
              p.dx + lean * 0.1, p.dy - th * 0.55, top.dx, top.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11 * px
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF4A3322));
    for (int i = 0; i < 7; i++) {
      final double a = -math.pi + (i + 0.5) * math.pi / 7;
      final double sw = math.sin(worldTime * 1.8 + i + idx) * 0.07;
      final double ca = math.cos(a + sw);
      final double sa = math.sin(a + sw);
      final Offset ctrl =
          Offset(top.dx + ca * 30 * px, top.dy + sa * 38 * px - 10 * px);
      final Offset end =
          Offset(top.dx + ca * 54 * px, top.dy + sa * 22 * px + 26 * px);
      canvas.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, 6 * px)
            ..strokeCap = StrokeCap.round
            ..color =
                i.isEven ? const Color(0xFF3E7A3A) : const Color(0xFF2F6030));
    }
    final Paint nut = Paint()..color = const Color(0xFF6B4A2A);
    canvas.drawCircle(Offset(top.dx - 4 * px, top.dy + 5 * px), 4.5 * px, nut);
    canvas.drawCircle(Offset(top.dx + 5 * px, top.dy + 6 * px), 4.5 * px, nut);
  }

  /// เฟิร์นยักษ์ (พุ่มใบโค้งเป็นพัด)
  void drawFern(Canvas canvas, Offset p, double px, int idx) {
    groundShadow(canvas, p, 70 * px, 9 * px);
    for (int i = 0; i < 9; i++) {
      final double a = -math.pi + 0.3 + i * (math.pi - 0.6) / 8;
      final double len = (36 + (i % 3) * 10) * px;
      final double sw = math.sin(worldTime * 2.0 + i + idx) * 0.05;
      final double ca = math.cos(a + sw);
      final double sa = math.sin(a + sw);
      final Offset end = Offset(p.dx + ca * len, p.dy + sa * len * 1.25);
      final Offset ctrl =
          Offset(p.dx + ca * len * 0.45, p.dy + sa * len * 1.7);
      final Path leaf = Path()
        ..moveTo(p.dx, p.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      canvas.drawPath(
          leaf,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, 5 * px)
            ..strokeCap = StrokeCap.round
            ..color =
                i.isEven ? const Color(0xFF3A6B35) : const Color(0xFF4F8A45));
      canvas.drawPath(
          leaf,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.8, 1.2 * px)
            ..color = const Color(0x66C8F0A0));
    }
  }

  /// ปรง (cycad): ลำต้นอ้วนสั้น มียอดใบแหลมและโคนสีส้ม
  void drawCycad(Canvas canvas, Offset p, double px, int idx) {
    groundShadow(canvas, p, 70 * px, 10 * px);
    final double th = (46 + (idx % 3) * 8) * px;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(p.dx - 12 * px, p.dy - th, 24 * px, th),
            Radius.circular(9 * px)),
        Paint()..color = const Color(0xFF5A4030));
    final Paint scale = Paint()
      ..color = const Color(0xFF3A2A1E)
      ..strokeWidth = math.max(1.0, 1.6 * px);
    for (int j = 0; j < 4; j++) {
      final double y = p.dy - th + (j + 0.5) * th / 4;
      canvas.drawLine(
          Offset(p.dx - 10 * px, y), Offset(p.dx + 10 * px, y + 4 * px), scale);
      canvas.drawLine(
          Offset(p.dx + 10 * px, y), Offset(p.dx - 10 * px, y + 4 * px), scale);
    }
    final Offset top = Offset(p.dx, p.dy - th);
    for (int i = 0; i < 9; i++) {
      final double a = -math.pi + 0.25 + i * (math.pi - 0.5) / 8;
      final double len = (50 + (i % 2) * 10) * px;
      final double sw = math.sin(worldTime * 1.6 + i * 0.7 + idx) * 0.05;
      final double ca = math.cos(a + sw);
      final double sa = math.sin(a + sw);
      final Offset end = Offset(top.dx + ca * len, top.dy + sa * len * 0.8 + 12 * px);
      final Offset ctrl =
          Offset(top.dx + ca * len * 0.55, top.dy + sa * len * 0.9 - 12 * px);
      canvas.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, 5 * px)
            ..strokeCap = StrokeCap.round
            ..color =
                i.isEven ? const Color(0xFF2F5E32) : const Color(0xFF3F7A3A));
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(top.dx, top.dy - 2 * px),
            width: 14 * px,
            height: 18 * px),
        Paint()..color = const Color(0xFFB8742C));
  }

  /// รังไข่ไดโนเสาร์ (บางรังมีลูกไดโนเสาร์กำลังฟักโผล่หัว)
  void drawEggNest(Canvas canvas, Offset p, double px, int idx) {
    groundShadow(canvas, p, 76 * px, 11 * px);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(p.dx, p.dy - 4 * px), width: 68 * px, height: 22 * px),
        Paint()..color = const Color(0xFF5A3C20));
    final Paint straw = Paint()
      ..color = const Color(0xFF8A6A3A)
      ..strokeWidth = math.max(1.0, 2 * px)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 9; i++) {
      final double x = -30.0 + i * 7.5;
      canvas.drawLine(Offset(p.dx + x * px, p.dy - 2 * px),
          Offset(p.dx + (x + (i.isEven ? 5 : -4)) * px, p.dy - 10 * px), straw);
    }
    const List<Color> eggCol = [
      Color(0xFFE8DCC0),
      Color(0xFFDDE8C0),
      Color(0xFFC9E0D0),
      Color(0xFFF0D8B8),
    ];
    const List<List<double>> pos = [
      [-16, -14],
      [3, -17],
      [19, -12],
      [-3, -7],
    ];
    final bool hatch = idx % 3 == 0;
    final int n = 3 + idx % 2;
    for (int i = 0; i < n; i++) {
      final Offset c = Offset(p.dx + pos[i][0] * px, p.dy + pos[i][1] * px);
      if (hatch && i == 1) {
        // ลูกไดโนเสาร์โผล่จากไข่
        final double bob = math.sin(worldTime * 3 + idx) * 2 * px;
        canvas.drawCircle(Offset(c.dx, c.dy - 12 * px + bob), 8 * px,
            Paint()..color = const Color(0xFF5FB35A));
        canvas.drawCircle(Offset(c.dx - 3 * px, c.dy - 13 * px + bob),
            1.8 * px, Paint()..color = const Color(0xFF152B1E));
        canvas.drawCircle(Offset(c.dx + 3 * px, c.dy - 13 * px + bob),
            1.8 * px, Paint()..color = const Color(0xFF152B1E));
        // เปลือกไข่ครึ่งล่าง
        canvas.drawArc(
            Rect.fromCenter(center: c, width: 19 * px, height: 24 * px),
            0,
            math.pi,
            true,
            Paint()..color = eggCol[i]);
        continue;
      }
      canvas.drawOval(
          Rect.fromCenter(center: c, width: 18 * px, height: 23 * px),
          Paint()..color = eggCol[i]);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx - 3 * px, c.dy - 5 * px),
              width: 5 * px,
              height: 8 * px),
          Paint()..color = const Color(0x66FFFFFF));
      final Paint spot = Paint()..color = const Color(0xFF8A7A5A);
      canvas.drawCircle(Offset(c.dx + 3 * px, c.dy + 2 * px), 1.5 * px, spot);
      canvas.drawCircle(Offset(c.dx - 2 * px, c.dy + 6 * px), 1.2 * px, spot);
      canvas.drawCircle(Offset(c.dx + 4 * px, c.dy - 4 * px), 1.1 * px, spot);
    }
  }

  /// ไดโนเสาร์คอยาวยืนอยู่ริมทาง dir = 1 หันขวา / -1 หันซ้าย (หันเข้าหาทางวิ่ง)
  void drawBronto(Canvas canvas, Offset p, double px, int idx, double dir) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(dir * px * 1.5, px * 1.5);
    final Paint body = Paint()..color = const Color(0xFF6E7F4C);
    final Paint dark = Paint()..color = const Color(0xFF4A5A33);
    final Paint belly = Paint()..color = const Color(0xFF9BA876);

    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 150, height: 14),
        Paint()..color = const Color(0x33000000));

    // ขา (คู่หลังสีเข้มกว่า)
    for (final double lx in const [-30.0, 18.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(lx - 5, -30, 10, 30), const Radius.circular(4)),
          dark);
    }
    // หาง
    canvas.drawPath(
        Path()
          ..moveTo(-38, -50)
          ..quadraticBezierTo(-82, -44, -104, -10)
          ..quadraticBezierTo(-80, -30, -38, -30)
          ..close(),
        body);
    // ลำตัว
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -46), width: 92, height: 48),
        body);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -36), width: 70, height: 20),
        belly);
    for (final double lx in const [-14.0, 34.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(lx - 5, -32, 10, 32), const Radius.circular(4)),
          body);
    }
    // ลายจุดบนหลัง
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(-26.0 + i * 13, -58.0 + (i % 2) * 5), 3.2,
          Paint()..color = const Color(0x554A5A33));
    }
    // คอ + หัว (ส่ายเบาๆ)
    final double sw = math.sin(worldTime * 1.5 + idx) * 3;
    canvas.drawPath(
        Path()
          ..moveTo(32, -58)
          ..quadraticBezierTo(54, -82, 54 + sw, -114),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15
          ..strokeCap = StrokeCap.round
          ..color = body.color);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(60 + sw, -118), width: 26, height: 15),
        body);
    canvas.drawCircle(Offset(64 + sw, -120), 2.2,
        Paint()..color = const Color(0xFF24150E));
    canvas.restore();
  }

  /// สเตโกซอรัสยืนอยู่ริมทาง แผ่นหลังสีส้มรับแสงลาวา
  void drawStego(Canvas canvas, Offset p, double px, int idx, double dir) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(dir * px * 1.4, px * 1.4);
    final Paint body = Paint()..color = const Color(0xFF7A6A3F);
    final Paint dark = Paint()..color = const Color(0xFF55482A);

    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 130, height: 12),
        Paint()..color = const Color(0x33000000));

    for (final double lx in const [-26.0, 24.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(lx - 5, -24, 10, 24), const Radius.circular(4)),
          dark);
    }
    // หาง + หนามหาง
    canvas.drawPath(
        Path()
          ..moveTo(-36, -42)
          ..quadraticBezierTo(-70, -40, -94, -24)
          ..quadraticBezierTo(-70, -28, -36, -22)
          ..close(),
        body);
    final Paint bone = Paint()..color = const Color(0xFFE6D9BF);
    canvas.drawPath(
        Path()
          ..moveTo(-84, -27)
          ..lineTo(-96, -42)
          ..lineTo(-78, -30)
          ..close(),
        bone);
    canvas.drawPath(
        Path()
          ..moveTo(-92, -22)
          ..lineTo(-106, -34)
          ..lineTo(-86, -26)
          ..close(),
        bone);
    // ลำตัว
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -38), width: 86, height: 46),
        body);
    for (final double lx in const [-12.0, 36.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(lx - 5, -26, 10, 26), const Radius.circular(4)),
          body);
    }
    // แผ่นหลัง
    for (int i = 0; i < 6; i++) {
      final double x = -30.0 + i * 12.0;
      final double nx = (x / 43.0).clamp(-0.98, 0.98).toDouble();
      final double yTop = -38 - 23 * math.sqrt(1 - nx * nx) + 3;
      final double hgt = 20 - (i - 2.5).abs() * 3.2;
      canvas.drawPath(
          Path()
            ..moveTo(x - 7, yTop + 3)
            ..lineTo(x, yTop - hgt)
            ..lineTo(x + 7, yTop + 3)
            ..close(),
          Paint()..color = const Color(0xFFD2692F));
      canvas.drawLine(
          Offset(x, yTop - hgt + 3),
          Offset(x, yTop + 1),
          Paint()
            ..color = const Color(0xFFFFC65A)
            ..strokeWidth = 1.5);
    }
    // คอ + หัวเล็ก
    final double nod = math.sin(worldTime * 1.8 + idx) * 2;
    canvas.drawPath(
        Path()
          ..moveTo(36, -48)
          ..quadraticBezierTo(50, -42, 52, -30 + nod),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..color = body.color);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(56, -28 + nod), width: 26, height: 15),
        body);
    canvas.drawCircle(Offset(60, -31 + nod), 2,
        Paint()..color = const Color(0xFF24150E));
    canvas.restore();
  }

  /// เปลวไฟเล็กๆ ใช้ซ้ำในของตกแต่ง
  void flame(Canvas canvas, Offset b, double px, double seed, double size) {
    final double fh = (16 + math.sin(worldTime * 16 + seed) * 6) * size;
    canvas.drawPath(
        poly([
          Offset(b.dx - 7 * px * size, b.dy),
          Offset(b.dx, b.dy - fh * px),
          Offset(b.dx + 7 * px * size, b.dy),
        ]),
        Paint()..color = const Color(0xFFFF7B35));
    canvas.drawPath(
        poly([
          Offset(b.dx - 3.5 * px * size, b.dy),
          Offset(b.dx, b.dy - fh * 0.6 * px),
          Offset(b.dx + 3.5 * px * size, b.dy),
        ]),
        Paint()..color = const Color(0xFFFFC65A));
  }

  void drawDeadTree(Canvas canvas, Offset p, double px, int idx) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 60 * px, height: 10 * px),
      Paint()..color = const Color(0x33000000),
    );
    final double th = (130 + (idx % 3) * 25) * px;
    final Paint wood = Paint()
      ..color = const Color(0xFF2A1D18)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    wood.strokeWidth = 13 * px;
    canvas.drawLine(p, Offset(p.dx + 3 * px, p.dy - th), wood);
    wood.strokeWidth = 6 * px;
    canvas.drawLine(Offset(p.dx + 1 * px, p.dy - th * 0.5),
        Offset(p.dx - 38 * px, p.dy - th * 0.78), wood);
    canvas.drawLine(Offset(p.dx + 2 * px, p.dy - th * 0.65),
        Offset(p.dx + 36 * px, p.dy - th * 0.92), wood);
    canvas.drawLine(Offset(p.dx + 3 * px, p.dy - th * 0.9),
        Offset(p.dx - 14 * px, p.dy - th * 1.12), wood);

    // บางต้นยังมีไฟลุกที่ปลายกิ่ง
    if (idx % 4 == 0) {
      flame(canvas, Offset(p.dx + 36 * px, p.dy - th * 0.92), px, idx * 1.0, 1.0);
    }
  }

  void drawRocks(Canvas canvas, Offset p, double px) {
    Offset q(double dx, double dy) => Offset(p.dx + dx * px, p.dy + dy * px);
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 100 * px, height: 12 * px),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawPath(
        poly([q(-30, 0), q(-26, -34), q(-4, -52), q(22, -40), q(30, 0)]),
        Paint()..color = const Color(0xFF4D3B35));
    canvas.drawPath(poly([q(-26, -34), q(-4, -52), q(2, -24), q(-18, -8)]),
        Paint()..color = const Color(0xFF6E5A50));
    canvas.drawPath(poly([q(26, 0), q(30, -20), q(46, -24), q(56, 0)]),
        Paint()..color = const Color(0xFF3E2F2A));
  }

  void drawBones(Canvas canvas, Offset p, double px) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 120 * px, height: 12 * px),
      Paint()..color = const Color(0x33000000),
    );
    final Paint bone = Paint()
      ..color = const Color(0xFFE6D9BF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    bone.strokeWidth = 6 * px;
    canvas.drawLine(
        Offset(p.dx - 45 * px, p.dy - 8 * px),
        Offset(p.dx + 45 * px, p.dy - 8 * px),
        bone);
    bone.strokeWidth = 4 * px;
    for (int i = 0; i < 5; i++) {
      final double x = p.dx + (-36 + i * 17) * px;
      canvas.drawPath(
          Path()
            ..moveTo(x, p.dy - 8 * px)
            ..quadraticBezierTo(
                x + 6 * px, p.dy - 48 * px, x + 15 * px, p.dy - 6 * px),
          bone);
    }
    // กะโหลก
    final Paint fill = Paint()..color = const Color(0xFFE6D9BF);
    canvas.drawCircle(Offset(p.dx + 58 * px, p.dy - 14 * px), 12 * px, fill);
    canvas.drawRect(
        Rect.fromLTWH(p.dx + 58 * px, p.dy - 12 * px, 18 * px, 9 * px), fill);
    canvas.drawCircle(Offset(p.dx + 56 * px, p.dy - 17 * px), 3 * px,
        Paint()..color = const Color(0xFF24150E));
  }

  void drawLavaPool(Canvas canvas, Offset p, double px) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 150 * px, height: 32 * px),
      Paint()..color = const Color(0xFF2A1410),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 120 * px, height: 24 * px),
      Paint()..color = const Color(0xFFFF6A35),
    );
    final double pulse = 0.8 + 0.2 * math.sin(worldTime * 4 + p.dx);
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 64 * pulse * px, height: 12 * px),
      Paint()..color = const Color(0xFFFFC65A),
    );
    // ฟองลาวา
    for (int j = 0; j < 3; j++) {
      final double ph = (worldTime * 1.2 + j * 0.33) % 1.0;
      final double bx = p.dx + (-30 + j * 30) * px;
      final double by = p.dy - ph * 26 * px;
      canvas.drawCircle(Offset(bx, by), (4 - ph * 3) * px,
          Paint()..color = Color.fromARGB(al(230 * (1 - ph)), 255, 170, 70));
    }
  }

  /// เสาซากปรักหักพังที่หักครึ่ง มีไฟลุกบางต้น
  void drawRuin(Canvas canvas, Offset p, double px, int idx) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 90 * px, height: 12 * px),
      Paint()..color = const Color(0x33000000),
    );
    final double ph = (95 + (idx % 3) * 20) * px;
    final Paint stone = Paint()..color = const Color(0xFF5C4A44);
    final Path col = Path()
      ..moveTo(p.dx - 16 * px, p.dy)
      ..lineTo(p.dx - 16 * px, p.dy - ph)
      ..lineTo(p.dx - 6 * px, p.dy - ph - 9 * px)
      ..lineTo(p.dx - 1 * px, p.dy - ph + 4 * px)
      ..lineTo(p.dx + 7 * px, p.dy - ph - 6 * px)
      ..lineTo(p.dx + 16 * px, p.dy - ph + 2 * px)
      ..lineTo(p.dx + 16 * px, p.dy)
      ..close();
    canvas.drawPath(col, stone);
    canvas.drawRect(
        Rect.fromLTWH(p.dx + 5 * px, p.dy - ph + 2 * px, 11 * px, ph),
        Paint()..color = const Color(0x33000000));
    final Paint crack = Paint()
      ..color = const Color(0xFF2E221E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.8 * px);
    canvas.drawPath(
        Path()
          ..moveTo(p.dx - 8 * px, p.dy - ph * 0.9)
          ..lineTo(p.dx - 2 * px, p.dy - ph * 0.6)
          ..lineTo(p.dx - 9 * px, p.dy - ph * 0.35),
        crack);
    canvas.drawRect(
        Rect.fromLTWH(p.dx - 22 * px, p.dy - 8 * px, 44 * px, 8 * px),
        Paint()..color = const Color(0xFF3E2F2A));
    // ท่อนเสาที่ล้มอยู่
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(p.dx + 38 * px, p.dy - 6 * px),
            width: 34 * px,
            height: 14 * px),
        stone);
    if (idx % 2 == 0) {
      flame(canvas, Offset(p.dx + 2 * px, p.dy - ph), px, idx * 1.3, 1.2);
    }
  }

  /// ซี่โครงไดโนเสาร์ยักษ์โผล่จากพื้น
  void drawGiantRibs(Canvas canvas, Offset p, double px) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 130 * px, height: 12 * px),
      Paint()..color = const Color(0x33000000),
    );
    final Paint rib = Paint()
      ..color = const Color(0xFFE6D9BF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, 7 * px);
    for (int i = 0; i < 4; i++) {
      final double x = -36.0 + i * 24.0;
      final double tipY = -64.0 - (i % 2) * 18.0;
      canvas.drawPath(
          Path()
            ..moveTo(p.dx + x * px, p.dy)
            ..quadraticBezierTo(p.dx + (x - 20) * px, p.dy - 56 * px,
                p.dx + (x + 22) * px, p.dy + tipY * px),
          rib);
      canvas.drawCircle(Offset(p.dx + x * px, p.dy - 2 * px), 6 * px,
          Paint()..color = const Color(0xFFCDBE9F));
    }
  }

  /// กองไฟ/ซากไหม้
  void drawFirePit(Canvas canvas, Offset p, double px, int idx) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 90 * px, height: 16 * px),
      Paint()..color = const Color(0x55000000),
    );
    glow(canvas, Offset(p.dx, p.dy - 14 * px), 55 * px,
        (110 + 40 * math.sin(worldTime * 9 + idx)).round());
    for (int i = 0; i < 6; i++) {
      final double a = i * math.pi / 3;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(p.dx + math.cos(a) * 24 * px,
                  p.dy + math.sin(a) * 6 * px),
              width: 14 * px,
              height: 8 * px),
          Paint()..color = const Color(0xFF3E2F2A));
    }
    flame(canvas, Offset(p.dx - 10 * px, p.dy - 2 * px), px, idx * 1.0, 1.3);
    flame(canvas, Offset(p.dx + 9 * px, p.dy - 2 * px), px, idx * 1.0 + 2, 1.1);
    flame(canvas, Offset(p.dx, p.dy), px, idx * 1.0 + 4, 1.7);
  }

  /// เสาปักกะโหลกพร้อมธงขาด
  void drawSkullPole(Canvas canvas, Offset p, double px, int idx) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 50 * px, height: 9 * px),
      Paint()..color = const Color(0x33000000),
    );
    final double ph = 125 * px;
    canvas.drawLine(
        p,
        Offset(p.dx, p.dy - ph),
        Paint()
          ..color = const Color(0xFF2A1D18)
          ..strokeWidth = 7 * px
          ..strokeCap = StrokeCap.round);
    // ธงขาดลู่ลม
    final double fl = math.sin(worldTime * 5 + idx) * 5 * px;
    canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - ph * 0.82)
          ..lineTo(p.dx + 34 * px + fl, p.dy - ph * 0.76)
          ..lineTo(p.dx + 24 * px, p.dy - ph * 0.68)
          ..lineTo(p.dx + 36 * px + fl, p.dy - ph * 0.58)
          ..lineTo(p.dx, p.dy - ph * 0.6)
          ..close(),
        Paint()..color = const Color(0xFF8E1F14));
    // กะโหลก
    final Paint bone = Paint()..color = const Color(0xFFE6D9BF);
    final Offset sk = Offset(p.dx, p.dy - ph - 12 * px);
    canvas.drawCircle(sk, 14 * px, bone);
    canvas.drawRect(
        Rect.fromLTWH(sk.dx - 8 * px, sk.dy + 8 * px, 16 * px, 9 * px), bone);
    canvas.drawCircle(Offset(sk.dx - 5 * px, sk.dy), 3.6 * px,
        Paint()..color = const Color(0xFF24150E));
    canvas.drawCircle(Offset(sk.dx + 5 * px, sk.dy), 3.6 * px,
        Paint()..color = const Color(0xFF24150E));
    canvas.drawCircle(Offset(sk.dx - 5 * px, sk.dy), 1.4 * px,
        Paint()..color = const Color(0xFFFF7B35));
    canvas.drawCircle(Offset(sk.dx + 5 * px, sk.dy), 1.4 * px,
        Paint()..color = const Color(0xFFFF7B35));
  }

  // ---------------------------------------------------------------- objects

  void drawObject(Canvas canvas, GameObject obj) {
    final Offset p = gp(obj.lane.toDouble(), obj.d);
    final double px = u * sc(obj.d);

    if (obj.hit) {
      canvas.saveLayer(
          null, Paint()..color = const Color.fromARGB(110, 255, 255, 255));
    }

    if (obj.type != ObjectType.meat &&
        !(obj.type == ObjectType.meteor && !obj.landed)) {
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 100 * px, height: 14 * px),
        Paint()..color = const Color(0x33000000),
      );
    }

    switch (obj.type) {
      case ObjectType.skeleton:
        drawSkeleton(canvas, p, px, obj.variant);
        break;
      case ObjectType.meteor:
        drawMeteor(canvas, obj, p, px);
        break;
      case ObjectType.meat:
        final double bob = math.sin(worldTime * 5 + obj.d * 0.02) * 3 * px;
        paintMeat(canvas, p.dx, p.dy - obj.h * px + bob, 30 * px);
        break;
    }

    if (obj.hit) canvas.restore();
  }

  /// โครงกระดูกยักษ์: ใต้โครงโล่ง ม้วนตัวลอดได้ / สูง ต้องกระโดด 2 ครั้ง
  void drawSkeleton(Canvas canvas, Offset p, double px, int variant) {
    Offset q(double dx, double dy) => Offset(p.dx + dx * px, p.dy + dy * px);
    final Paint bone = Paint()..color = const Color(0xFFE6D9BF);
    final Paint shade = Paint()..color = const Color(0xFFB9A98A);
    final Paint dark = Paint()..color = const Color(0xFF24150E);

    // เสาซ้าย-ขวา (กระดูกต้นขา)
    for (final double sx in const [-46.0, 46.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(p.dx + (sx - 5) * px, p.dy - 112 * px, 10 * px,
                  112 * px),
              Radius.circular(4 * px)),
          bone);
      canvas.drawRect(
          Rect.fromLTWH(p.dx + (sx + 1) * px, p.dy - 106 * px, 3.5 * px,
              100 * px),
          shade);
      canvas.drawCircle(q(sx - 4, -112), 7 * px, bone);
      canvas.drawCircle(q(sx + 4, -112), 7 * px, bone);
      canvas.drawCircle(q(sx - 4, -3), 7 * px, bone);
      canvas.drawCircle(q(sx + 4, -3), 7 * px, bone);
    }

    if (variant == 0) {
      // กระดูกสันหลังพาดบน + ซี่โครงห้อยลง + กะโหลก
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(p.dx - 52 * px, p.dy - 128 * px, 104 * px, 20 * px),
              Radius.circular(8 * px)),
          bone);
      final Paint seg = Paint()
        ..color = dark.color
        ..strokeWidth = math.max(1.0, 1.5 * px);
      for (int i = 0; i < 8; i++) {
        final double x = -44.0 + i * 12.5;
        canvas.drawLine(q(x, -126), q(x, -110), seg);
      }
      final Paint rib = Paint()
        ..color = bone.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.5, 4.5 * px);
      for (int i = 0; i < 6; i++) {
        final double x = -33.0 + i * 13.2;
        final Offset a = q(x, -108);
        final Offset c = q(x + (i.isEven ? 9 : -9), -82);
        final Offset b = q(x, -52);
        canvas.drawPath(
            Path()
              ..moveTo(a.dx, a.dy)
              ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy),
            rib);
      }
      // กะโหลกบนสุด
      canvas.drawCircle(q(0, -124), 14 * px, bone);
      canvas.drawRect(
          Rect.fromLTWH(p.dx - 8 * px, p.dy - 118 * px, 16 * px, 9 * px), bone);
      canvas.drawCircle(q(-5.5, -126), 3.8 * px, dark);
      canvas.drawCircle(q(5.5, -126), 3.8 * px, dark);
      canvas.drawCircle(
          q(-5.5, -126), 1.5 * px, Paint()..color = const Color(0xFFFF5A36));
      canvas.drawCircle(
          q(5.5, -126), 1.5 * px, Paint()..color = const Color(0xFFFF5A36));
    } else {
      // กะโหลกที-เร็กซ์ขนาดใหญ่พาดบน มีฟันแหลมห้อยลง
      canvas.drawPath(
          poly([
            q(-50, -100),
            q(-46, -124),
            q(-30, -135),
            q(30, -135),
            q(46, -124),
            q(50, -100),
          ]),
          bone);
      canvas.drawRect(
          Rect.fromLTWH(p.dx - 50 * px, p.dy - 104 * px, 100 * px, 6 * px),
          shade);
      canvas.drawOval(
          Rect.fromCenter(center: q(-22, -118), width: 20 * px, height: 24 * px),
          dark);
      canvas.drawOval(
          Rect.fromCenter(center: q(22, -118), width: 20 * px, height: 24 * px),
          dark);
      canvas.drawCircle(
          q(-22, -116), 3 * px, Paint()..color = const Color(0xFFFF5A36));
      canvas.drawCircle(
          q(22, -116), 3 * px, Paint()..color = const Color(0xFFFF5A36));
      canvas.drawOval(
          Rect.fromCenter(center: q(0, -112), width: 8 * px, height: 12 * px),
          dark);
      for (int i = 0; i < 9; i++) {
        final double x = -44.0 + i * 11.0;
        canvas.drawPath(poly([q(x, -100), q(x + 5.5, -80), q(x + 11, -100)]),
            bone);
        canvas.drawLine(
            q(x + 5.5, -100),
            q(x + 5.5, -82),
            Paint()
              ..color = shade.color
              ..strokeWidth = math.max(0.8, 1.0 * px));
      }
    }
  }

  void drawMeteor(Canvas canvas, GameObject obj, Offset p, double px) {
    if (!obj.landed) {
      // วงเตือนบนพื้น
      final double t = (1.0 - obj.h / 1100.0).clamp(0.0, 1.0).toDouble();
      final int a = (40 + 150 * t).round();
      final Rect ring =
          Rect.fromCenter(center: p, width: 95 * px, height: 30 * px);
      canvas.drawOval(ring,
          Paint()..color = Color.fromARGB((a * 0.5).round(), 255, 60, 40));
      canvas.drawOval(
        ring,
        Paint()
          ..color = Color.fromARGB(a, 255, 90, 60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 3 * px).toDouble(),
      );

      final double size = 42 * px;
      final double cy = p.dy - obj.h * px - 20 * px;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(p.dx, cy - size * 0.9),
            width: size * 0.7,
            height: size * 1.8),
        Paint()..color = const Color(0xFFFF7B35),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(p.dx, cy - size * 0.7),
            width: size * 0.4,
            height: size * 1.2),
        Paint()..color = const Color(0xFFFFC65A),
      );
      canvas.drawCircle(Offset(p.dx, cy), size * 0.45,
          Paint()..color = const Color(0xFF755044));
      canvas.drawCircle(Offset(p.dx - size * 0.12, cy - size * 0.12),
          size * 0.13, Paint()..color = const Color(0xFFFFC65A));
      return;
    }

    // ตกถึงพื้นแล้ว: กลายเป็นก้อนหินไฟ (โดดข้ามได้)
    canvas.drawCircle(Offset(p.dx, p.dy - 20 * px), 50 * px,
        Paint()..color = const Color(0x44FF7B35));
    Offset q(double dx, double dy) => Offset(p.dx + dx * px, p.dy + dy * px);
    final Path rock = Path()
      ..moveTo(q(-40, 0).dx, q(-40, 0).dy)
      ..lineTo(q(-34, -26).dx, q(-34, -26).dy)
      ..lineTo(q(-10, -45).dx, q(-10, -45).dy)
      ..lineTo(q(22, -38).dx, q(22, -38).dy)
      ..lineTo(q(40, -12).dx, q(40, -12).dy)
      ..lineTo(q(38, 0).dx, q(38, 0).dy)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF4A3A34));
    final Paint crack = Paint()
      ..color = const Color(0xFFFF7B35)
      ..strokeWidth = math.max(1.0, 3 * px).toDouble();
    canvas.drawLine(q(-20, -8), q(-6, -30), crack);
    canvas.drawLine(q(10, -6), q(24, -26), crack);
    for (int j = 0; j < 3; j++) {
      final double fh = 14 + math.sin(worldTime * 18 + j) * 6;
      final double fx = -15.0 + j * 15.0;
      canvas.drawPath(
        Path()
          ..moveTo(q(fx - 6, -40).dx, q(fx - 6, -40).dy)
          ..lineTo(q(fx, -40 - fh).dx, q(fx, -40 - fh).dy)
          ..lineTo(q(fx + 6, -40).dx, q(fx + 6, -40).dy)
          ..close(),
        Paint()..color = const Color(0xFFFFA23A),
      );
    }
    if (obj.impactT > 0) {
      final double t = 1.0 - obj.impactT / 0.35;
      canvas.drawOval(
        Rect.fromCenter(
            center: p, width: (60 + 120 * t) * px, height: (20 + 40 * t) * px),
        Paint()
          ..color = Color.fromARGB((200 * (1 - t)).round(), 255, 180, 80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 4 * px).toDouble(),
      );
    }
  }

  // ----------------------------------------------------------------- player

  void drawPlayer(Canvas canvas) {
    final double x = w / 2 + laneX * laneW;

    // เงา เล็กลง/จางลงเมื่อลอยสูง
    final double height = jumpY.clamp(0.0, 200.0).toDouble();
    final double t = 1.0 - height / 200.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, playerY + 2 * u),
        width: (30 + 26 * t) * u,
        height: (8 + 4 * t) * u,
      ),
      Paint()..color = Color.fromARGB((30 + 60 * t).round(), 0, 0, 0),
    );

    // กะพริบตอนอมตะชั่วคราวหลังโดนชน
    if (invuln > 0 && (invuln * 10).floor() % 2 == 0) return;

    drawDinosaur(canvas, x, playerY - jumpY * u);
  }

  void drawDinosaur(Canvas canvas, double x, double y) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(u * (1.0 - stretch * 0.6), u * (1.0 + stretch));

    final double flip = flipProgress < 1.0
        ? easeOutCubic(flipProgress) * 2.0 * math.pi
        : 0.0;
    canvas.translate(0, -38);
    canvas.rotate(dinoTilt + flip);
    canvas.translate(0, 38);

    DinoSprite.draw(
      canvas,
      skin,
      t: worldTime,
      phase: runPhase,
      air: airBlend,
      roll: rollBlend,
      rollAngle: rollAngle,
      run: running,
    );

    canvas.restore();
  }

  // -------------------------------------------------------------------- HUD

  void drawHud(Canvas canvas) {
    final double fs = u.clamp(0.8, 1.4).toDouble();
    final double y = topInset + 10;

    // หัวใจ (ซ้ายบน) — ปุ่ม Pause อยู่ใต้หัวใจ (วางเป็น widget)
    drawText(canvas, '${'♥' * lives}${'♡' * (3 - lives)}', 14.0, y, 24.0 * fs,
        const Color(0xFFFF4E59));

    // คะแนน = ระยะทาง (ขวาบน)
    drawText(canvas, 'SCORE  $score m', w - 14.0, y, 18.0 * fs, Colors.white,
        right: true);

    // ค่าเงิน (เนื้อสะสม) ใต้คะแนน
    final double yy = y + 26.0 * fs;
    final double tw = drawText(
        canvas, '$meat', w - 14.0, yy, 17.0 * fs, const Color(0xFFFFE16A),
        right: true);
    paintMeat(canvas, w - 14.0 - tw - 16.0 * fs, yy + 11.0 * fs, 22.0 * fs);

    drawText(canvas, 'TIME  ${elapsed.floor()}s', w / 2, y, 16.0 * fs,
        Colors.white,
        center: true);

    // ความเร็วเพิ่มทุก 300 เมตร
    if (speedUpTimer > 0) {
      final double a = ((speedUpTimer * 6).floor() % 2 == 0) ? 1.0 : 0.55;
      drawText(canvas, 'SPEED UP!  LV ${level + 1}', w / 2, y + 24.0 * fs,
          14.0 * fs, Color.fromARGB(al(255 * a), 255, 225, 106),
          center: true);
    } else {
      drawText(canvas, 'LV ${level + 1}', w / 2, y + 24.0 * fs, 12.0 * fs,
          Colors.white70,
          center: true);
    }
  }

  double drawText(Canvas canvas, String text, double x, double y,
      double fontSize, Color color,
      {bool center = false, bool right = false}) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2))
            ],
          )),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    double drawX = x;
    if (center) {
      drawX -= painter.width / 2;
    } else if (right) {
      drawX -= painter.width;
    }
    painter.paint(canvas, Offset(drawX, y));
    return painter.width;
  }

  @override
  bool shouldRepaint(covariant DinoPainter oldDelegate) => true;
}