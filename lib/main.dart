import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'player_page.dart';

const String kSupabaseUrl = 'https://' 'tvallstream-proxy.abiliorr.workers.dev/db';
const String kSupabaseAnonKey = 'sb_publishable_Q5jTnbrCs-dRi4PzrCHohA_wHYqSsYz';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TvAllStreamApp());
}

class TvAllStreamApp extends StatelessWidget {
  const TvAllStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVAllstream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0E101A)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String mac = 'Gerando MAC...';
  bool loading = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _initMac();
  }

  String _gen() {
    final r = Random();
    const h = '0123456789ABCDEF';
    return List.generate(6, (_) => '${h[r.nextInt(16)]}${h[r.nextInt(16)]}').join(':');
  }

  Future<void> _initMac() async {
    try {
      final p = await SharedPreferences.getInstance();
      var s = p.getString('device_mac');
      if (s == null || s.isEmpty) {
        s = _gen();
        await p.setString('device_mac', s);
      }
      if (mounted) setState(() => mac = s!);
    } catch (_) {
      if (mounted) setState(() => mac = _gen());
    }
  }

  Future<void> _connect() async {
    if (mac.startsWith('Gerando')) return;
    setState(() { loading = true; err = null; });
    try {
      final uri = Uri.parse('$kSupabaseUrl/rest/v1/mac_users?mac_address=eq.${Uri.encodeComponent(mac)}&select=*');
      final res = await http.get(uri, headers: {'apikey': kSupabaseAnonKey, 'Authorization': 'Bearer $kSupabaseAnonKey'});
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(account: list.first)));
        } else {
          setState(() => err = 'MAC não registrado ou aguardando ativação no painel.');
        }
      } else {
        setState(() => err = 'Erro Supabase (${res.statusCode})');
      }
    } catch (e) {
      setState(() => err = 'Falha de conexão: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E101A),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: const Color(0xFF171A29), borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.live_tv_rounded, size: 54, color: Color(0xFF5A48F5)),
              const SizedBox(height: 12),
              const Text('TVAllstream Player', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 22),
              const Text('SEU ENDEREÇO MAC:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Text(mac, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 22),
              if (err != null) ...[Text(err!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)), const SizedBox(height: 12)],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  autofocus: true,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A48F5), foregroundColor: Colors.white),
                  onPressed: loading ? null : _connect,
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('CONECTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
