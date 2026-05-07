import 'package:flutter/material.dart';

/// Shimmer-style skeleton placeholder ใช้แทน `CircularProgressIndicator` เต็มจอ
/// เพื่อให้ผู้ใช้รับรู้รูปทรงของเนื้อหาที่กำลังจะมา (ลด perceived loading time)
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFE0E0E0),
              const Color(0xFFF5F5F5),
              t,
            ),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

/// Skeleton สำหรับ home dashboard (เลียนแบบ header + stats grid + game card)
class HomeDashboardSkeleton extends StatelessWidget {
  const HomeDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 120,
      ),
      children: [
        // header (avatar + nickname + role badge)
        Row(
          children: const [
            SkeletonBox(
              width: 70,
              height: 70,
              borderRadius: BorderRadius.all(Radius.circular(35)),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 200, height: 22),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 24),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const SkeletonBox(width: 180, height: 20),
        const SizedBox(height: 15),
        // stats grid 2×2
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: List.generate(
            4,
            (_) => SkeletonBox(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const SkeletonBox(width: 180, height: 20),
        const SizedBox(height: 15),
        // game card placeholder
        SkeletonBox(
          height: 160,
          borderRadius: BorderRadius.circular(16),
        ),
      ],
    );
  }
}

/// Placeholder การ์ดก๊วน (สูงประมาณ GameCard / history card)
class SessionCardListSkeleton extends StatelessWidget {
  const SessionCardListSkeleton({
    super.key,
    this.itemCount = 5,
    this.padding = EdgeInsets.zero,
    this.bottomInset = 100,
  });

  final int itemCount;
  final EdgeInsets padding;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding.copyWith(bottom: padding.bottom + bottomInset),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SkeletonBox(
          height: 136,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Skeleton หน้ากระเป๋าเงิน — เลียนแบบการ์ดยอด + หัวข้อ + รายการธุรกรรม
class WalletPageSkeleton extends StatelessWidget {
  const WalletPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        SkeletonBox(
          height: 188,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 24),
        SkeletonBox(
          width: 140,
          height: 18,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          6,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonBox(
              height: 72,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Skeleton หน้าเกมของฉัน — หลายหัวข้อ + การ์ดจำลอง
class MyGamesPageSkeleton extends StatelessWidget {
  const MyGamesPageSkeleton({super.key});

  Widget _section() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            width: 110,
            height: 20,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 12),
          SkeletonBox(
            height: 136,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 12),
          SkeletonBox(
            height: 136,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _section(),
        _section(),
        _section(),
      ],
    );
  }
}
