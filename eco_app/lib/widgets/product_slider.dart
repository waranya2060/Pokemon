import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'package:intl/intl.dart';

class ProductSlider extends StatefulWidget {
  final List<Product> products;

  const ProductSlider({super.key, required this.products});

  @override
  State<ProductSlider> createState() => _ProductSliderState();
}

class _ProductSliderState extends State<ProductSlider> {
  late final PageController _pc;
  int _index = 0;
  final _fmt = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.82);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.products.length - 1);
    if (next == _index) return;
    _pc.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const SizedBox(height: 240, child: Center(child: Text('No products')));
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.products.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final p = widget.products[i];
              return AnimatedScale(
                scale: i == _index ? 1.0 : 0.95,
                duration: const Duration(milliseconds: 300),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: CachedNetworkImage(
                              imageUrl: p.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (c, _) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (c, _, __) => const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('${p.rating} (${p.reviewCount})'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_fmt.format(p.price),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.info_outline),
                                    label: const Text('Detail'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: const Text('Add'),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // ปุ่มซ้าย/ขวา
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                onPressed: () => _go(-1),
                icon: const Icon(Icons.chevron_left, size: 28),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                onPressed: () => _go(1),
                icon: const Icon(Icons.chevron_right, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
