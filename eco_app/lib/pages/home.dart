import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pb.dart';
import '../models/product.dart';
import '../models/shop.dart';
import '../models/review.dart';
import 'manage_products.dart'; // 👈 นำเข้า

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pb = PBService();
  final _fmt = NumberFormat.currency(locale: 'th_TH', symbol: '฿');
  final _pageCtrl = PageController(viewportFraction: .74);

  List<Shop> _topShops = [];
  List<Product> _topProducts = [];
  List<Review> _popularReviews = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final shops = await _pb.getTopShops();
      final prods = await _pb.getTopProducts(perPage: 40);
      final revs  = await _pb.getPopularReviews(perPage: 20);

      setState(() {
        _topShops = shops.map((r) => Shop.fromRecord(r.data)).toList();
        _topProducts = prods.map((r) => Product.fromRecord(r.data)).toList();
        _popularReviews = revs.map((r) => Review.fromRecord(r.data)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openManage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageProductsPage()),
    );
    // เมื่อกลับมาหน้านี้ รีโหลดข้อมูลให้ตรงกับที่แก้ในตาราง
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text(_error!)));

    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF7FF), Color(0xFFDFF1FF), Color(0xFFF7FBFF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(.65),
          elevation: 0,
          centerTitle: true,
          title: const Text('E-Commerce', style: TextStyle(fontWeight: FontWeight.w700)),
          // 🔘 ปุ่มเดียวใต้ชื่อ
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _openManage,
                icon: const Icon(Icons.table_chart_rounded),
                label: const Text('Manage Products '),
              ),
            ),
          ),
          actions: [
            IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
            const SizedBox(width: 6),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _sectionHeader(context, Icons.store_mall_directory_rounded, 'Top Shops'),
              const SizedBox(height: 8),
              _topShopsView(),

              const SizedBox(height: 18),
              _sectionHeader(context, Icons.star_rate_rounded, 'Top Products'),
              const SizedBox(height: 8),
              _productCarousel(cs),

              const SizedBox(height: 18),
              _sectionHeader(context, Icons.rate_review_rounded, 'Popular Reviews'),
              const SizedBox(height: 8),
              _reviewsList(),
            ],
          ),
        ),
      ),
    );
  }

  /* ------- เดิมของคุณด้านล่าง (ตัดไม่เปลี่ยนโครง) ------- */

  Widget _sectionHeader(BuildContext ctx, IconData icon, String title) {
    final cs = Theme.of(ctx).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(ctx).textTheme.headlineSmall),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('New', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _topShopsView() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _topShops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final s = _topShops[i];
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE3F0FF),
                backgroundImage: s.logoUrl.isEmpty ? null : NetworkImage(s.logoUrl),
                child: s.logoUrl.isEmpty ? Text(s.name.isNotEmpty ? s.name[0] : '?') : null,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 96,
                child: Text(
                  s.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _productCarousel(ColorScheme cs) {
    final h = 240.0;
    if (_topProducts.isEmpty) {
      return const SizedBox(height: 120, child: Center(child: Text('No products')));
    }
    return SizedBox(
      height: h,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            clipBehavior: Clip.none,
            itemCount: _topProducts.length,
            itemBuilder: (_, i) {
              final p = _topProducts[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Card(
                  color: Colors.white.withOpacity(.70),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 180, height: h - 24,
                          child: p.imageUrl.isEmpty
                              ? const ColoredBox(color: Color(0xFFE7E7E7))
                              : Image.network(p.imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(_fmt.format(p.price),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                                    label: const Text('Detail'),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: cs.primary),
                                    icon: const Icon(Icons.add_shopping_cart_rounded),
                                    label: const Text('Add'),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _roundIconButton(icon: Icons.chevron_left_rounded, onTap: () => _animatePage(-1)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _roundIconButton(icon: Icons.chevron_right_rounded, onTap: () => _animatePage(1)),
          ),
          Positioned(bottom: 4, left: 0, right: 0, child: _dots(activeColor: Colors.lightBlueAccent)),
        ],
      ),
    );
  }

  void _animatePage(int delta) {
    final max = _topProducts.isEmpty ? 0 : _topProducts.length - 1;
    final next = ((_pageCtrl.page ?? 0).round() + delta).clamp(0, max);
    _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Widget _roundIconButton({required IconData icon, required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: cs.primary.withOpacity(.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 22, color: Colors.black87)),
        ),
      ),
    );
  }

  Widget _dots({required Color activeColor}) {
    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (_, __) {
        final page = _pageCtrl.hasClients ? (_pageCtrl.page ?? 0.0) : 0.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(18, (i) {
            final active = (i - page).abs() < .5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 14 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: active ? activeColor : activeColor.withOpacity(.25),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _reviewsList() {
    if (_popularReviews.isEmpty) return const Text('No reviews yet');
    return Column(
      children: _popularReviews.take(4).map((r) {
        return Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.lightBlue),
            title: Text('${r.userName} • ⭐ ${r.rating}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(r.comment, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        );
      }).toList(),
    );
  }
}
