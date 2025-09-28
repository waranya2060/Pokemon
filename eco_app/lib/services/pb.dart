import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PBService {
  static final PBService _instance = PBService._internal();
  factory PBService() => _instance;

  late final PocketBase pb;

  PBService._internal() {
    final baseUrl = dotenv.env['PB_BASE_URL'] ?? 'http://127.0.0.1:8090';
    pb = PocketBase(baseUrl);
  }

  /// helper: กันหน้าแอปล่มเมื่อมี error — คืนลิสต์ว่างแทน
  Future<List<RecordModel>> _safeGet(
    Future<ResultList<RecordModel>> Function() call, {
    String? debugTag,
  }) async {
    try {
      final res = await call();
      return res.items;
    } on ClientException catch (e) {
      // ignore: avoid_print
      print('[PB $_logTs] $debugTag ClientException '
            '(status:${e.statusCode}) resp:${e.response}');
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('[PB $_logTs] $debugTag Unknown error: $e');
      return [];
    }
  }

  String get _logTs =>
      DateTime.now().toIso8601String().replaceFirst('T', ' ').split('.').first;

  // ---------- SHOPS ----------
  Future<List<RecordModel>> getTopShops() => _safeGet(
        () => pb.collection('shops').getList(
              page: 1,
              perPage: 20,
              filter: 'rating >= 4',
              sort: '-rating,name', // ไม่มีเว้นวรรค
            ),
        debugTag: 'getTopShops',
      );

  // ---------- PRODUCTS ----------
  Future<List<RecordModel>> getTopProducts({int perPage = 20}) => _safeGet(
        () => pb.collection('products').getList(
              page: 1,
              perPage: perPage,
              filter: 'isTop = true',
              sort: '-rating,-reviewCount', // ไม่มีเว้นวรรค
            ),
        debugTag: 'getTopProducts',
      );

  // ---------- REVIEWS ----------
  /// พยายาม sort โดย `-rating,-created` ถ้า schema ยังไม่มี `rating`
  /// จะ fallback เป็น `-created` อัตโนมัติ
  Future<List<RecordModel>> getPopularReviews({int perPage = 20}) async {
    try {
      final res = await pb.collection('reviews').getList(
            page: 1,
            perPage: perPage,
            sort: '-rating,-created', // ไม่มีเว้นวรรค
          );
      return res.items;
    } on ClientException catch (e) {
      // ignore: avoid_print
      print('[PB $_logTs] getPopularReviews primary sort failed '
            '(status:${e.statusCode}) -> fallback -created');
      // fallback: created เท่านั้น (ใช้ได้ทุกสคีมา)
      return _safeGet(
        () => pb.collection('reviews').getList(
              page: 1,
              perPage: perPage,
              sort: '-created',
            ),
        debugTag: 'getPopularReviews(fallback)',
      );
    }
  }

  // ---------- CRUD (products) ----------
  Future<RecordModel> createProduct(Map<String, dynamic> data) async {
    return await pb.collection('products').create(body: data);
  }

  Future<RecordModel> updateProduct(String id, Map<String, dynamic> data) async {
    return await pb.collection('products').update(id, body: data);
  }

  Future<void> deleteProduct(String id) async {
    await pb.collection('products').delete(id);
  }

  // dev-only: admin auth สำหรับ seed/ทดสอบ
  Future<void> adminLogin() async {
    final email = dotenv.env['PB_ADMIN_EMAIL']!;
    final pw = dotenv.env['PB_ADMIN_PASSWORD']!;
    await pb.admins.authWithPassword(email, pw);
  }
}
