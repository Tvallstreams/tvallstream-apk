import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'player_page.dart';

const String kSupabaseUrl = 'https://' 'ihzzgtkavekrvgsxshhy.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_Q5jTnbrCs-dRi4PzrCHohA_wHYqSsYz';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String macAddress = 'Gerando MAC...';
  bool loading = false;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateMac();
  }

  String _randomMac() {
    final rnd = Random();
    const hex = '0123456789ABCDEF';
    return List.generate(6, (_) => '${hex[rnd.nextInt(16)]}${hex[rnd.nextInt(16)]}').join(':');
  }

  Future<void> _loadOrGenerateMac() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? saved = prefs.getString('device_mac');
      if (saved == null || saved.isEmpty) {
        saved = _randomMac();
        await prefs.setString('device_mac', saved);
      }
      if (mounted) setState(() => macAddress = saved!);
    } catch (_) {
      if (mounted) setState(() => macAddress = _randomMac());
    }
  }

  Future<void> _connect() async {
    if (macAddress.isEmpty || macAddress.startsWith('Gerando')) return;
    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final uri = Uri.parse(
        '$kSupabaseUrl/rest/v1/mac_users?mac_address=eq.${Uri.encodeComponent(macAddress)}&select=*',
      );
      final res = await http.get(uri, headers: {
        'apikey': kSupabaseAnonKey,
        'Authorization': 'Bearer $kSupabaseAnonKey',
      });

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final user = data.first as Map<String, dynamic>;
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerPage(account: user)),
          );
        } else {
          setState(() => errorMsg = 'MAC não registrado ou aguardando ativação no painel.');
        }
      } else {
        setState(() => errorMsg = 'Erro Supabase (${res.statusCode})');
      }
    } catch (e) {
      setState(() => errorMsg = 'Falha de conexão: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E101A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF171A29),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.live_tv_rounded, size: 54, color: Color(0xFF5A48F5)),
                const SizedBox(height: 12),
                const Text(
                  'TVAllstream Player',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text('SEU ENDEREÇO MAC:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  macAddress,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                ),
                const SizedBox(height: 24),
                if (errorMsg != null) ...[
                  Text(errorMsg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  const SizedBox(height: 14),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    autofocus: true,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A48F5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: loading ? null : _connect,
                    child: loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('CONECTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
