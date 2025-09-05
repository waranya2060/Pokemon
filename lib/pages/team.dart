import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final box = GetStorage();

  List<Map<String, String>> teamMembers = [];
  List<Map<String, dynamic>> savedTeams = [];
  List<Map<String, String>> pokemonsList = [];

  List<String> types = [];
  String selectedType = '';
  bool isLoading = false;
  String teamName = '';

  late TextEditingController teamNameController;

  @override
  void initState() {
    super.initState();
    teamNameController = TextEditingController();
    loadSavedTeams();
    fetchPokemons();
  }

  @override
  void dispose() {
    teamNameController.dispose();
    super.dispose();
  }

  void loadSavedTeams() {
    final stored = box.read<List>('savedTeams');
    if (stored != null) {
      setState(() {
        savedTeams = stored.map((e) {
          final team = Map<String, dynamic>.from(e);
          team['members'] = (team['members'] as List)
              .map((m) => Map<String, String>.from(m))
              .toList();
          return team;
        }).toList();
      });
    }
  }

  Future<void> fetchPokemons() async {
    setState(() => isLoading = true);
    try {
      final response =
          await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=50'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, String>> tempList = [];
        List<String> tempTypes = [];

        for (var e in data['results']) {
          final url = e['url'];
          final detailResp = await http.get(Uri.parse(url));
          if (detailResp.statusCode == 200) {
            final detail = json.decode(detailResp.body);
            final pokeTypes = (detail['types'] as List)
                .map((t) => t['type']['name'] as String)
                .toList();

            for (var t in pokeTypes) {
              if (!tempTypes.contains(t)) tempTypes.add(t);
            }

            tempList.add({
              'name': e['name'],
              'imageUrl':
                  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${data['results'].indexOf(e) + 1}.png',
              'types': pokeTypes.join(','),
            });
          }
        }

        setState(() {
          pokemonsList = tempList;
          types = tempTypes;
        });
      }
    } catch (_) {
      // ignore
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<Map<String, String>> get filteredPokemonsByType {
    if (selectedType.isEmpty) return pokemonsList;
    return pokemonsList.where((p) => p['types']!.contains(selectedType)).toList();
  }

  void togglePokemon(Map<String, String> p) {
    setState(() {
      final exists = teamMembers.any((m) => m['name'] == p['name']);
      if (exists) {
        teamMembers.removeWhere((m) => m['name'] == p['name']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('นำออกจากทีมแล้ว')),
        );
        return;
      }
      if (teamMembers.length >= 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทีมเต็มแล้ว (สูงสุด 6 ตัว)')),
        );
        return;
      }
      teamMembers.add({'name': p['name'] ?? '', 'imageUrl': p['imageUrl'] ?? ''});
    });
  }

  void saveTeam() {
    final name = teamNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาตั้งชื่อทีม')),
      );
      return;
    }
    if (teamMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลือกโปเกมอนอย่างน้อย 1 ตัว')),
      );
      return;
    }

    final stored = box.read<List>('savedTeams') ?? [];
    final current = stored.map((e) => Map<String, dynamic>.from(e)).toList();

    final payload = {
      'name': name,
      'members': teamMembers
          .map((m) => {'name': m['name'] ?? '', 'imageUrl': m['imageUrl'] ?? ''})
          .toList(),
    };

    final idx = current.indexWhere((t) => (t['name'] as String?) == name);
    if (idx >= 0) {
      current[idx] = payload;
    } else {
      current.add(payload);
    }

    box.write('savedTeams', current);
    setState(() {
      savedTeams = current;
      teamName = '';
      teamMembers.clear();
      teamNameController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(idx >= 0 ? 'อัปเดตทีมเรียบร้อย' : 'บันทึกทีมเรียบร้อย')),
    );
  }

  void removeTeam(int index) {
    final name = savedTeams[index]['name'] as String? ?? 'ทีมนี้';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบทีม'),
        content: Text('ต้องการลบทีม "$name" ใช่ไหม?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () {
              setState(() {
                savedTeams.removeAt(index);
                box.write('savedTeams', savedTeams);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ลบทีมเรียบร้อย')),
              );
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void editTeam(int index) {
    final team = savedTeams[index];
    String tempName = (team['name'] as String?) ?? '';
    List<Map<String, String>> tempMembers =
        List<Map<String, String>>.from(team['members'] as List);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('แก้ไขทีม'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'ชื่อทีม',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: tempName),
                    onChanged: (v) => tempName = v.trim(),
                  ),
                  const SizedBox(height: 12),
                  const Text('สมาชิกทีม', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tempMembers.isEmpty
                        ? [const Text('ไม่มีสมาชิก', style: TextStyle(color: Colors.grey))]
                        : tempMembers.map((m) {
                            return Chip(
                              label: Text(_capitalize(m['name'] ?? '-')),
                              avatar: (m['imageUrl'] ?? '').isNotEmpty
                                  ? CircleAvatar(backgroundImage: NetworkImage(m['imageUrl']!))
                                  : const CircleAvatar(child: Icon(Icons.catching_pokemon)),
                              deleteIcon: const Icon(Icons.close),
                              onDeleted: () {
                                setLocal(() {
                                  tempMembers.removeWhere((x) => x['name'] == m['name']);
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
              FilledButton(
                onPressed: () {
                  final updated = {
                    'name': tempName.isEmpty ? (team['name'] as String? ?? '') : tempName,
                    'members': tempMembers
                        .map((m) => {'name': m['name'] ?? '', 'imageUrl': m['imageUrl'] ?? ''})
                        .toList(),
                  };

                  setState(() {
                    savedTeams[index] = updated;
                    box.write('savedTeams', savedTeams);

                    teamName = updated['name'] as String;
                    teamMembers =
                        List<Map<String, String>>.from(updated['members'] as List);
                    teamNameController.text = teamName;
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('บันทึกการแก้ไขแล้ว')),
                  );
                },
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- UI Helpers (Glass + Blob) ----------
  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            blurRadius: 60,
            spreadRadius: 10,
            color: color.withOpacity(.35),
          ),
        ],
      ),
    );
  }

  Widget _glass({required Widget child, double radius = 16, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.6)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                offset: Offset(0, 8),
                color: Color(0x14000000),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // การ์ดทีมสไตล์ใหม่ (glass)
  Widget savedTeamCard(Map<String, dynamic> team, int index) {
    final members = List<Map<String, String>>.from(team['members'] as List);

    return _glass(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    team['name'] as String? ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => editTeam(index),
                  icon: const Icon(Icons.edit, size: 18),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  color: Colors.black87,
                ),
                IconButton(
                  onPressed: () => removeTeam(index),
                  icon: const Icon(Icons.delete, size: 18),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  color: Colors.black87,
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = members[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p['imageUrl'] ?? '',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 60,
                        child: Text(
                          _capitalize(p['name'] ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFDDE3EE)),
                  ),
                  child: Text(
                    '${members.length}/6 ตัว',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  
  Widget buildTopEditor() {
    return _glass(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สร้าง/แก้ไขทีม',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: teamNameController,
            decoration: InputDecoration(
              hintText: 'ตั้งชื่อทีม',
              prefixIcon: const Icon(Icons.groups_2_outlined),
              filled: true,
              fillColor: Colors.white.withOpacity(.7),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => teamName = v.trim(),
          ),
          const SizedBox(height: 12),
          const Text('สมาชิกที่เลือก', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: teamMembers.isEmpty
                ? [const Text('ยังไม่ได้เลือกโปเกมอน', style: TextStyle(color: Colors.black54))]
                : teamMembers.map((m) {
                    return Chip(
                      label: Text(_capitalize(m['name'] ?? '-')),
                      avatar: (m['imageUrl'] ?? '').isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(m['imageUrl']!))
                          : const CircleAvatar(child: Icon(Icons.catching_pokemon)),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => togglePokemon(m),
                      backgroundColor: Colors.white.withOpacity(.75),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(28),
                      ),
                    );
                  }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () {
                    setState(() {
                      teamMembers.clear();
                    });
                  },
                  child: const Text('ล้างทีม'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: saveTeam,
                  child: const Text('บันทึกทีม'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  String capitalize(String s) => _capitalize(s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Pokémon Team Builder'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF1F1), Color(0xFFF3E8FF), Color(0xFFE6F4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -60, right: -40, child: _blob(180, const Color(0xFFFFCDD2).withOpacity(.45))),
          Positioned(bottom: -80, left: -50, child: _blob(220, const Color(0xFFB39DDB).withOpacity(.35))),

          // เนื้อหา
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // แถบเลือก/แก้ไขทีม — อยู่ด้านบนสุด (glass)
                  buildTopEditor(),

                  // ทีมของฉัน (การ์ดใหม่)
                  if (savedTeams.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        const Text('ทีมของฉัน',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: savedTeams.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) =>
                                savedTeamCard(savedTeams[index], index),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: types
                          .map((type) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(
                                    _capitalize(type),
                                    style: TextStyle(
                                      color: selectedType == type ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  selected: selectedType == type,
                                  selectedColor: Colors.black,
                                  onSelected: (val) {
                                    setState(() {
                                      selectedType = val ? type : '';
                                    });
                                  },
                                  backgroundColor: Colors.white.withOpacity(.75),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: BorderSide(
                                      color: selectedType == type
                                          ? Colors.black
                                          : const Color(0xFFE5E7EB),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: filteredPokemonsByType.length,
                            itemBuilder: (context, index) {
                              final p = filteredPokemonsByType[index];
                              final isSelected =
                                  teamMembers.any((m) => m['name'] == p['name']);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.85),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                      offset: Offset(0, 4),
                                      color: Color(0x12000000),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF111111)
                                        : const Color(0xFFE5E7EB),
                                    width: isSelected ? 2 : 1.2,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => togglePokemon(p),
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 120),
                                    scale: isSelected ? 0.98 : 1.0,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 1,
                                          child: Padding(
                                            padding: const EdgeInsets.all(6.0),
                                            child: Image.network(p['imageUrl']!, fit: BoxFit.contain),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _capitalize(p['name']!),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: Colors.black,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
