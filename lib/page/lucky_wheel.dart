import 'package:fashionmobile/services/network_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Prize {
  final String label;
  final Color color;
  final String? code;
  final String? value;
  final String? discountType;

  Prize({
    required this.label,
    required this.color,
    this.code,
    this.value,
    this.discountType,
  });
}

class LuckyWheel extends StatefulWidget {
  final int userId;
  final VoidCallback onClose;

  const LuckyWheel({
    Key? key,
    required this.userId,
    required this.onClose,
  }) : super(key: key);

  @override
  State<LuckyWheel> createState() => _LuckyWheelState();
}

class _LuckyWheelState extends State<LuckyWheel>
    with SingleTickerProviderStateMixin {
  static const String baseUrl = NetworkService.defaultIp;

  static final List<Prize> prizes = [
    Prize(
      label: 'Giảm 10%',
      color: Color(0xFFFF6B6B),
      code: 'SPIN10',
      value: '10%',
      discountType: 'percentage',
    ),
    Prize(
      label: 'Giảm 5%',
      color: Color(0xFF4ECDC4),
      code: 'SPIN5',
      value: '5%',
      discountType: 'percentage',
    ),
    Prize(
      label: 'Giảm 50K',
      color: Color(0xFFFF9F43),
      code: 'SPIN50K',
      value: '50.000đ',
      discountType: 'fixed',
    ),
    Prize(
      label: 'Chúc bạn may mắn lần sau',
      color: Color(0xFFBBBBBB),
      code: null,
      value: null,
      discountType: null,
    ),
    Prize(
      label: 'Giảm 20%',
      color: Color(0xFFE056FD),
      code: 'SPIN20',
      value: '20%',
      discountType: 'percentage',
    ),
    Prize(
      label: 'Giảm 100K',
      color: Color(0xFFF53B57),
      code: 'SPIN100K',
      value: '100.000đ',
      discountType: 'fixed',
    ),
    Prize(
      label: 'Giảm 1%',
      color: Color(0xFF5F27CD),
      code: 'SPIN1',
      value: '1%',
      discountType: 'percentage',
    ),
    Prize(
      label: 'Giảm 15%',
      color: Color(0xFF0ABDE3),
      code: 'SPIN15',
      value: '15%',
      discountType: 'percentage',
    ),
  ];

  static const int BETTER_LUCK_INDEX = 3;
  static const int COOLDOWN_SECONDS = 10;

  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  bool _canSpin = true;
  int _countdown = 0;
  Prize? _selectedPrize;
  bool _showResult = false;
  String? _saveStatus;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _checkSpinEligibility();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSpinEligibility() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpinTime = prefs.getInt('lastSpinTime');

    if (lastSpinTime == null) {
      setState(() {
        _canSpin = true;
        _countdown = 0;
      });
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final secondsPassed = (now - lastSpinTime) / 1000;
    final secondsUntilNextSpin =
        math.max(0, (COOLDOWN_SECONDS - secondsPassed).ceil());

    setState(() {
      _canSpin = secondsPassed >= COOLDOWN_SECONDS;
      _countdown = _canSpin ? 0 : secondsUntilNextSpin;
    });

    if (!_canSpin) {
      Future.delayed(const Duration(seconds: 1), _checkSpinEligibility);
    }
  }

  Future<void> _saveVoucherToAPI(Prize prize) async {
    if (prize.code == null) return;

    try {
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(hours: 24));

      int discountValue;
      if (prize.discountType == 'percentage') {
        discountValue = int.parse(prize.value!.replaceAll('%', ''));
      } else {
        discountValue =
            int.parse(prize.value!.replaceAll(RegExp(r'[^\d]'), ''));
      }

      final voucherData = {
        'code': prize.code,
        'discountType': prize.discountType,
        'discountValue': discountValue,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'used': false,
        'userId': widget.userId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/vouchers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(voucherData),
      );

      setState(() {
        _saveStatus = response.statusCode == 200 ? 'success' : 'error';
      });
    } catch (e) {
      setState(() {
        _saveStatus = 'error';
      });
    }
  }

  void _spinWheel() async {
    if (_isSpinning || !_canSpin) return;

    setState(() {
      _isSpinning = true;
      _showResult = false;
      _selectedPrize = null;
      _saveStatus = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSpinTime', DateTime.now().millisecondsSinceEpoch);

    // Determine winning prize with weighted probability
    int prizeIndex;
    if (math.Random().nextDouble() < 0.1) {
      prizeIndex = BETTER_LUCK_INDEX;
    } else {
      final otherPrizes = List.generate(prizes.length, (i) => i)
          .where((i) => i != BETTER_LUCK_INDEX)
          .toList();
      prizeIndex = otherPrizes[math.Random().nextInt(otherPrizes.length)];
    }

    final segmentAngle = 360 / prizes.length;
    final targetAngle = 360 * 5 - (prizeIndex * segmentAngle) + (segmentAngle / 2);

    // Điều chỉnh lại index thực sự trúng
    final realPrizeIndex = (prizeIndex - 1 + prizes.length) % prizes.length;
    final prize = prizes[realPrizeIndex];

    _animation = Tween<double>(
      begin: _animation.value,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward(from: 0).then((_) {
      setState(() {
        _isSpinning = false;
        _selectedPrize = prize;
        _showResult = true;
      });

      if (prize.code != null) {
        _saveVoucherToAPI(prize);
      }

      _checkSpinEligibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vòng quay may mắn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (!_showResult) ...[
              Text(
                _canSpin
                    ? 'Quay để nhận mã giảm giá đặc biệt!'
                    : 'Vui lòng đợi $_countdown giây trước khi quay tiếp.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              if (!_canSpin && _countdown > 0)
                LinearProgressIndicator(
                  value: _countdown / COOLDOWN_SECONDS,
                  backgroundColor: Colors.grey[200],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                width: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pointer
                    Positioned(
                      top: 0,
                      child: CustomPaint(
                        size: const Size(20, 20),
                        painter: PointerPainter(),
                      ),
                    ),
                    // Wheel
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _animation.value * (math.pi / 180),
                          child: CustomPaint(
                            size: const Size(280, 280),
                            painter: WheelPainter(prizes),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _canSpin ? _spinWheel : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSpin ? Colors.purple : Colors.grey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(
                  _isSpinning
                      ? 'Đang quay...'
                      : _canSpin
                          ? 'Quay ngay!'
                          : 'Đợi $_countdown giây',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold, // Tuỳ chọn: in đậm
                    fontSize: 16,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _selectedPrize!.color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _selectedPrize!.value ?? '!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _selectedPrize!.code != null
                    ? 'Chúc mừng! Bạn đã nhận được:'
                    : 'Chúc bạn may mắn lần sau',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedPrize!.code != null) ...[
                const SizedBox(height: 10),
                Text(_selectedPrize!.label),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedPrize!.code!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          // Implement copy functionality
                        },
                      ),
                    ],
                  ),
                ),
                if (_saveStatus == 'success')
                  const Text(
                    'Mã giảm giá đã được lưu vào tài khoản của bạn',
                    style: TextStyle(color: Colors.green),
                  ),
                if (_saveStatus == 'error')
                  const Text(
                    'Có lỗi khi lưu mã giảm giá. Vui lòng thử lại sau.',
                    style: TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Mã giảm giá có hiệu lực trong 24 giờ',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onClose,
                child: const Text('Đóng'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Prize> prizes;

  WheelPainter(this.prizes);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * math.pi / prizes.length;

    for (var i = 0; i < prizes.length; i++) {
      final paint = Paint()
        ..color = prizes[i].color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * segmentAngle - math.pi / 2,
        segmentAngle,
        true,
        paint,
      );

      // Vẽ text nằm ngang, căn giữa, không xoay
      final textSpan = TextSpan(
        text: prizes[i].label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      textPainter.layout(minWidth: 0, maxWidth: radius * 0.9);

      // Tính toán vị trí text nằm giữa segment, bắt đầu từ -90 độ
      final angle = i * segmentAngle + segmentAngle / 2 - math.pi / 2;
      final textRadius = radius * 0.65;
      final offset = Offset(
        center.dx + textRadius * math.cos(angle) - textPainter.width / 2,
        center.dy + textRadius * math.sin(angle) - textPainter.height / 2,
      );

      // Vẽ nền cho text (tùy chọn)
      final bgRect = Rect.fromCenter(
        center: Offset(
          center.dx + textRadius * math.cos(angle),
          center.dy + textRadius * math.sin(angle),
        ),
        width: textPainter.width + 12,
        height: textPainter.height + 6,
      );
      final bgPaint = Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
        bgPaint,
      );

      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
