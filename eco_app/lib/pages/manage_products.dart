import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pb.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  final _pb = PBService();
  final _fmt = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

  // scroll controllers เพื่อแสดง scrollbar ทั้งแนวตั้ง/แนวนอน
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  List<RecordModel> _all = [];
  List<RecordModel> _filtered = [];
  bool _loading = true;
  String _q = '';
  bool _onlyTop = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      // ไม่ส่ง sort/skipTotal เพื่อเลี่ยง 400 บางเวอร์ชัน
      _all = await _pb.pb.collection('products').getFullList(batch: 200);
      // เรียงฝั่ง client (ล่าสุดก่อน)
      _all.sort((a, b) {
        final ac = a.created;
        final bc = b.created;
        if (ac == null || bc == null) return 0;
        return bc.compareTo(ac);
      });
    } catch (_) {
      // fallback: ไล่หน้าเอง
      try {
        final items = <RecordModel>[];
        var page = 1;
        const perPage = 50;
        while (true) {
          final res = await _pb.pb.collection('products').getList(
                page: page,
                perPage: perPage,
              );
          items.addAll(res.items);
          if (res.items.length < perPage) break;
          page++;
        }
        _all = items;
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Load error: $e2')),
          );
        }
      }
    } finally {
      _applyFilter();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _q.trim().toLowerCase();
    _filtered = _all.where((r) {
      final name = (r.data['name'] ?? '').toString().toLowerCase();
      final isTop = (r.data['isTop'] ?? false) == true;
      final matchQ = q.isEmpty ? true : name.contains(q);
      final matchTop = _onlyTop ? isTop : true;
      return matchQ && matchTop;
    }).toList();
    setState(() {});
  }

  Future<void> _createOrEdit({RecordModel? rec}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditDialog(pb: _pb, rec: rec),
    );
    if (result == true) {
      await _reload();
    }
  }

  Future<void> _delete(RecordModel rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text('ลบสินค้า "${rec.data['name']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _pb.adminLogin(); // ให้ตรงกับ rules ของคุณ
      await _pb.deleteProduct(rec.id);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ค้นหาชื่อสินค้า…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: cs.surface.withOpacity(.7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: cs.outline.withOpacity(.4)),
                      ),
                    ),
                    onChanged: (v) {
                      _q = v;
                      _applyFilter();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Top only'),
                  selected: _onlyTop,
                  onSelected: (v) {
                    _onlyTop = v;
                    _applyFilter();
                  },
                  selectedColor: cs.primaryContainer.withOpacity(.8),
                  side: BorderSide(color: cs.outline.withOpacity(.4)),
                ),
              ],
            ),
          ),
        ),
      ),
      // ❌ ลบ FAB (Add Product) ออกแล้ว
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _centeredTableCard(context),
    );
  }

  /// การ์ดตารางอยู่ "กลางหน้า" + เลื่อนทั้งสองแนวได้
  Widget _centeredTableCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final table = DataTable(
      columns: const [
        DataColumn(label: Text('Image')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Price')),
        DataColumn(label: Text('Rating')),
        DataColumn(label: Text('Top')),
        DataColumn(label: Text('Actions')),
      ],
      rows: _filtered.asMap().entries.map((entry) {
        final idx = entry.key;
        final r = entry.value;
        final d = r.data;

        final img = (d['imageUrl'] ?? '').toString();
        final name = (d['name'] ?? '').toString();

        double toDouble(dynamic v, [double def = 0]) {
          if (v is num) return v.toDouble();
          return double.tryParse(v?.toString() ?? '') ?? def;
        }

        final price = toDouble(d['price']);
        final rating = toDouble(d['rating']);
        final isTop = (d['isTop'] ?? false) == true;

        final bg = idx.isEven ? Colors.transparent : Colors.black.withOpacity(.02);

        return DataRow(
          color: MaterialStateProperty.all(bg),
          cells: [
            DataCell(
              SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: img.isEmpty
                      ? const ColoredBox(color: Color(0xFFE7E7E7))
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE7E7E7)),
                        ),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 280,
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            DataCell(Text(_fmt.format(price))),
            DataCell(Text(rating.toStringAsFixed(1))),
            DataCell(
              Icon(isTop ? Icons.check_circle : Icons.remove_circle,
                  color: isTop ? Colors.green : Colors.grey),
            ),
            DataCell(
              Wrap(
                spacing: 6,
                children: [
                  Tooltip(
                    message: 'Edit',
                    child: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _createOrEdit(rec: r),
                    ),
                  ),
                  Tooltip(
                    message: 'Delete',
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _delete(r),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );

    final themedTable = DataTableTheme(
      data: DataTableThemeData(
        headingRowColor: MaterialStateProperty.all(cs.primaryContainer.withOpacity(.45)),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        dividerThickness: 0.6,
        dataRowColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return cs.primary.withOpacity(.06);
          }
          return null;
        }),
      ),
      child: table,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100), // ✅ กำหนดความกว้างสูงสุดเพื่อให้อยู่กลาง
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withOpacity(.15)),
              boxShadow: const [
                BoxShadow(blurRadius: 18, spreadRadius: -6, offset: Offset(0, 6), color: Color(0x1A000000)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Scrollbar(
                controller: _vCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _vCtrl,
                  padding: const EdgeInsets.all(12),
                  child: Scrollbar(
                    controller: _hCtrl,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.depth == 1,
                    child: SingleChildScrollView(
                      controller: _hCtrl,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1000),
                        child: themedTable,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------- Dialog: Create/Edit -------------------- */

class _EditDialog extends StatefulWidget {
  final PBService pb;
  final RecordModel? rec;
  const _EditDialog({required this.pb, this.rec});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _image;
  double _rating = 4.5;
  bool _isTop = true;

  @override
  void initState() {
    super.initState();
    final d = widget.rec?.data ?? {};
    _name  = TextEditingController(text: d['name']?.toString() ?? '');
    _price = TextEditingController(text: (d['price'] ?? 199).toString());
    _image = TextEditingController(text: d['imageUrl']?.toString() ?? '');
    _rating = (d['rating'] is num)
        ? (d['rating'] as num).toDouble()
        : double.tryParse(d['rating']?.toString() ?? '') ?? 4.5;
    _isTop = (d['isTop'] ?? true) == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    try {
      await widget.pb.adminLogin(); // ให้ตรงกับ rules ของคุณ
      final body = {
        'name': _name.text.trim(),
        'price': double.parse(_price.text.trim()),
        'imageUrl': _image.text.trim(),
        'rating': double.parse(_rating.toStringAsFixed(1)),
        'isTop': _isTop,
      };
      if (widget.rec == null) {
        await widget.pb.createProduct(body);
      } else {
        await widget.pb.updateProduct(widget.rec!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.rec != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (THB)'),
                validator: (v) {
                  final p = double.tryParse(v ?? '');
                  if (p == null || p < 0) return 'Invalid price';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _image,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Rating'),
                  Expanded(
                    child: Slider(
                      value: _rating,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: _rating.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _rating = v),
                    ),
                  ),
                  SizedBox(width: 40, child: Text(_rating.toStringAsFixed(1))),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Top product'),
                value: _isTop,
                onChanged: (v) => setState(() => _isTop = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.primary),
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
