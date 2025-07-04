import 'package:fashionmobile/services/network_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

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

  List<Prize> _prizes = [];
  bool _loadingPrizes = false;
  String? _prizesError;
  int? _countWheel;
  bool _loadingCount = false;

  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
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
    _fetchPrizes();
    _fetchCountWheel();
  }

  Future<void> _fetchPrizes() async {
    setState(() {
      _loadingPrizes = true;
      _prizesError = null;
    });
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/prizes'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _prizes = data.map((e) => Prize(
            label: e['label'],
            color: Color(int.parse(e['color'].replaceFirst('#', '0xFF'))),
            code: e['code'],
            value: e['value'],
            discountType: e['discountType'],
          )).toList();
        });
      } else {
        setState(() {
          _prizesError = 'Lỗi khi lấy danh sách phần thưởng';
        });
      }
    } catch (e) {
      setState(() {
        _prizesError = 'Lỗi khi lấy danh sách phần thưởng';
      });
    } finally {
      setState(() {
        _loadingPrizes = false;
      });
    }
  }

  Future<void> _fetchCountWheel() async {
    setState(() {
      _loadingCount = true;
    });
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/users/${widget.userId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _countWheel = data['countWheel'] ?? 0;
        });
      } else {
        setState(() {
          _countWheel = 0;
        });
      }
    } catch (e) {
      setState(() {
        _countWheel = 0;
      });
    } finally {
      setState(() {
        _loadingCount = false;
      });
    }
  }

  Future<void> _decrementCountWheel() async {
  try {
    final getResponse = await http.get(Uri.parse('$baseUrl/api/users/${widget.userId}'));
    if (getResponse.statusCode != 200) {
      print('Lỗi khi lấy user: ${getResponse.body}');
      return;
    }

    final currentUser = json.decode(getResponse.body);
    final currentCount = currentUser["countWheel"] ?? 0;

    if (currentCount <= 0) {
      print('User không còn lượt quay');
      return;
    }

    final updatedUser = {
      "id": currentUser["id"],
      "username": currentUser["username"],
      "password": currentUser["password"], // Đã mã hóa nên giữ nguyên
      "email": currentUser["email"],
      "address": currentUser["address"],
      "phone": currentUser["phone"],
      "role": currentUser["role"],
      "verificationToken": null,
      "countWheel": currentCount - 1,
      "active": currentUser["active"],
    };

    print('Sending PUT with countWheel: ${updatedUser["countWheel"]}');

    final putResponse = await http.put(
      Uri.parse('$baseUrl/api/users/${widget.userId}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(updatedUser),
    );

    print('PUT response: ${putResponse.statusCode}');
    print('PUT response body: ${putResponse.body}');

    if (putResponse.statusCode == 200) {
      setState(() {
        _countWheel = currentCount - 1;
      });
    }
  } catch (e) {
    print('Lỗi giảm countWheel: $e');
  }
}


  bool get _canUserSpin => (_countWheel ?? 0) > 0 && !_isSpinning && !_loadingPrizes && !_loadingCount;

  Future<void> _saveVoucherToAPI(Prize prize) async {
    if (prize.code == null) return;
    try {
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(hours: 24));
      int discountValue;
      if (prize.discountType == 'percentage') {
        discountValue = int.parse(prize.value!.replaceAll('%', ''));
      } else {
        discountValue = int.parse(prize.value!.replaceAll(RegExp(r'[^\d]'), ''));
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
    if (!_canUserSpin) return;
    setState(() {
      _isSpinning = true;
      _showResult = false;
      _selectedPrize = null;
      _saveStatus = null;
    });
    // Xác suất trúng "Chúc bạn may mắn lần sau" 10%
    int betterLuckIndex = _prizes.indexWhere((p) => p.label.toLowerCase().contains('may mắn'));
    int prizeIndex;
    if (math.Random().nextDouble() < 0.1 && betterLuckIndex != -1) {
      prizeIndex = betterLuckIndex;
    } else {
      final otherPrizes = List.generate(_prizes.length, (i) => i).where((i) => i != betterLuckIndex).toList();
      prizeIndex = otherPrizes[math.Random().nextInt(otherPrizes.length)];
    }
    final segmentAngle = 360 / _prizes.length;
    final targetAngle = 360 * 5 - (prizeIndex * segmentAngle) + (segmentAngle / 2);
    final prize = _prizes[prizeIndex];
    _animation = Tween<double>(
      begin: _animation.value,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward(from: 0).then((_) async {
      await _decrementCountWheel(); // Trừ lượt quay NGAY SAU khi quay xong
      setState(() {
        _isSpinning = false;
        _selectedPrize = prize;
        _showResult = true;
      });
      if (prize.code != null) {
        await _saveVoucherToAPI(prize);
      }
      await _fetchCountWheel(); // Đảm bảo đồng bộ lượt quay mới nhất từ server
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: _loadingPrizes || _loadingCount
            ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
            : _prizesError != null
                ? SizedBox(height: 300, child: Center(child: Text(_prizesError!)))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Vòng quay may mắn',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_countWheel != null)
                        Text(
                          'Lượt quay còn lại: $_countWheel',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (!_showResult) ...[
                        Text(
                          _canUserSpin
                              ? 'Quay để nhận mã giảm giá đặc biệt!'
                              : 'Bạn không có lượt quay nào cả.',
                          style: const TextStyle(fontSize: 16),
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
                                      painter: WheelPainter(_prizes),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _canUserSpin ? _spinWheel : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canUserSpin ? Colors.purple : Colors.grey,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: Text(
                            _isSpinning
                                ? 'Đang quay...'
                                : _canUserSpin
                                    ? 'Quay ngay!'
                                    : 'Hết lượt quay',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                                fontSize: 18,
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
                                    // Copy code to clipboard
                                    Clipboard.setData(ClipboardData(text: _selectedPrize!.code!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đã sao chép mã!')),
                                    );
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
