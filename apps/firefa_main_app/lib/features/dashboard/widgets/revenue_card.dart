import 'dart:math' as math;

import 'package:flutter/material.dart';

class RevenueCard extends StatefulWidget {
  const RevenueCard({super.key});

  @override
  State<RevenueCard> createState() => _RevenueCardState();
}

class _RevenueCardState extends State<RevenueCard> {
  int selectedPeriod = 7;
  int? selectedPoint;

  static const Color primary = Color(0xFF009688);
  static const Color dark = Color(0xFF172B4D);
  static const Color muted = Color(0xFF64748B);

  final List<double> weeklySales = const [4.2, 5.8, 4.9, 7.1, 6.4, 8.5, 7.8];

  final List<double> monthlySales = List.generate(
    30,
    (i) =>
        3.5 + (i * 0.12) + math.sin(i * 0.8) * 1.2 + math.cos(i * 0.35) * 0.7,
  );

  List<double> get sales => selectedPeriod == 7 ? weeklySales : monthlySales;

  double get totalSales => sales.fold(0.0, (sum, value) => sum + value);

  String formatRupiah(double million) {
    final amount = (million * 1000000).round();
    final digits = amount.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return 'Rp ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final currentSales = sales;
    final pointIndex = selectedPoint == null
        ? currentSales.length - 1
        : selectedPoint!.clamp(0, currentSales.length - 1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;

              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue Overview',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Ringkasan performa penjualan',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              );

              final periodSelector = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _periodButton('7 Hari', 7),
                  const SizedBox(width: 8),
                  _periodButton('30 Hari', 30),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 16),
                    periodSelector,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  periodSelector,
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          const Text(
            'Total Revenue',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(totalSales),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: dark,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.trending_up, color: primary, size: 19),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Data simulasi penjualan FIREFA',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FAF9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hari ${pointIndex + 1}  •  ${formatRupiah(currentSales[pointIndex])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: dark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _selectPoint(details.localPosition.dx, chartWidth);
                },
                onHorizontalDragUpdate: (details) {
                  _selectPoint(details.localPosition.dx, chartWidth);
                },
                child: SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _RevenueChartPainter(
                      values: currentSales,
                      selectedIndex: pointIndex,
                      color: primary,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedPeriod == 7 ? 'Hari 1' : 'Hari 1',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                'Hari $selectedPeriod',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(color: Color(0xFFEDF1F5)),

          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sales Revenue',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
              const Icon(Icons.info_outline, color: muted, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodButton(String label, int period) {
    final active = selectedPeriod == period;

    return Material(
      color: active ? primary : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          setState(() {
            selectedPeriod = period;
            selectedPoint = null;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : muted,
            ),
          ),
        ),
      ),
    );
  }

  void _selectPoint(double x, double width) {
    if (width <= 0 || sales.length < 2) return;

    final normalized = (x / width).clamp(0.0, 1.0);
    final index = (normalized * (sales.length - 1)).round();

    if (selectedPoint != index) {
      setState(() {
        selectedPoint = index;
      });
    }
  }
}

class _RevenueChartPainter extends CustomPainter {
  final List<double> values;
  final int selectedIndex;
  final Color color;

  _RevenueChartPainter({
    required this.values,
    required this.selectedIndex,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    const topPadding = 16.0;
    const bottomPadding = 16.0;

    final chartHeight = size.height - topPadding - bottomPadding;

    final maximum = values.reduce(math.max) * 1.2;

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDF2)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight * i / 4;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset position(int index) {
      final x = values.length == 1
          ? size.width / 2
          : index * size.width / (values.length - 1);

      final y = topPadding + chartHeight * (1 - values[index] / maximum);

      return Offset(x, y);
    }

    final linePath = Path();
    final first = position(0);

    linePath.moveTo(first.dx, first.dy);

    for (int i = 1; i < values.length; i++) {
      final point = position(i);
      linePath.lineTo(point.dx, point.dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(size.width, size.height - bottomPadding)
      ..lineTo(0, size.height - bottomPadding)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.01)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(linePath, linePaint);

    final selected = position(selectedIndex.clamp(0, values.length - 1));

    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(selected.dx, topPadding),
      Offset(selected.dx, size.height - bottomPadding),
      guidePaint,
    );

    canvas.drawCircle(selected, 7, Paint()..color = Colors.white);

    canvas.drawCircle(selected, 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.values != values ||
        oldDelegate.color != color;
  }
}
