import 'dart:math';
import 'package:faker/faker.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:pocketbase/pocketbase.dart';

Future<void> main() async {
  // โหลดตัวแปรจาก .env (ต้องรันจากโฟลเดอร์ที่มีไฟล์ .env)
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load();

  final baseUrl    = env['PB_BASE_URL'] ?? 'http://127.0.0.1:8090';
  final adminEmail = env['PB_ADMIN_EMAIL']!;
  final adminPw    = env['PB_ADMIN_PASSWORD']!;

  final pb = PocketBase(baseUrl);
  await pb.admins.authWithPassword(adminEmail, adminPw);
  print('✅ Admin login OK → $baseUrl');

  final faker = Faker();
  final rnd = Random();

  // ----- ensure some shops -----
  final existingShops = await pb.collection('shops').getFullList();
  if (existingShops.isEmpty) {
    for (var i = 0; i < 8; i++) {
      await pb.collection('shops').create(body: {
        'name': faker.company.name(),
        'logoUrl': 'https://picsum.photos/seed/shop$i/200/200',
        'rating': double.parse((rnd.nextDouble() * 1.5 + 3.5).clamp(3.5, 5.0).toStringAsFixed(1)),
        'city': faker.address.city(),
        'isTop': i < 4,
      });
    }
  }

  final shops = await pb.collection('shops').getFullList();
  final shopIds = shops.map((s) => s.id).toList();

  // ----- seed 100 products -----
  final existingProducts = await pb.collection('products').getFullList();
  final startIndex = existingProducts.length;
  const total = 100;

  for (var i = startIndex; i < total; i++) {
    final shopId = shopIds[rnd.nextInt(shopIds.length)];
    final price = (rnd.nextDouble() * 1900 + 100).roundToDouble(); // 100..2000
    final rating = double.parse((rnd.nextDouble() * 2 + 3).clamp(3.0, 5.0).toStringAsFixed(1));
    final reviewCount = rnd.nextInt(400);

    final created = await pb.collection('products').create(body: {
      'name': '${faker.food.cuisine()} ${faker.food.dish()}',
      'price': price,
      'imageUrl': 'https://picsum.photos/seed/p$i/600/600',
      'rating': rating,
      'reviewCount': reviewCount,
      'shop': shopId,
      'isTop': i < 20,
    });

    final rp = rnd.nextInt(3); // 0..2 reviews
    for (var j = 0; j < rp; j++) {
      await pb.collection('reviews').create(body: {
        'product': created.id,
        'userName': faker.person.name(),
        'rating': double.parse((rnd.nextDouble() * 2 + 3).clamp(3.0, 5.0).toStringAsFixed(1)),
        'comment': faker.lorem.sentence(),
      });
    }

    if ((i + 1) % 10 == 0) {
      print('  → seeded ${i + 1} / $total');
    }
  }

  print(' Seed complete. Created up to $total products (first 20 set as Top).');
}
