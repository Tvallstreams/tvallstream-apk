import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const String kSupabaseUrl = 'https://' 'tvallstream-proxy.abiliorr.workers.dev/db';
const String kSupabaseAnonKey = 'sb_publishable_Q5jTnbrCs-dRi4PzrCHohA_wHYqSsYz';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TvAllStreamApp());
}

class TvAllStreamApp extends StatelessWidget {
  const TvAllStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TvAllStream TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0D17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6352FF),
          secondary: Color(0xFF00D2FF),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 68});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B61FF), Color(0xFF3B28CC)],
        ),
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x666352FF),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.live_tv_rounded, size: size * 0.56, color: Colors.white),
          Positioned(
            right: size * 0.14,
            bottom: size * 0.14,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF00D2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, size: size * 0.22, color: const Color(0xFF0B0D17)),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String macAddress = 'Gerando MAC...';
  bool loading = false;
  bool connectFocused = false;
  bool manualFocused = false;
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

  Future<void> _connectWithMac() async {
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
            MaterialPageRoute(builder: (_) => DashboardPage(account: user, macAddress: macAddress)),
          );
        } else {
          setState(() => errorMsg = 'MAC não ativado. Informe o MAC ao seu provedor ou adicione uma playlist.');
        }
      } else {
        setState(() => errorMsg = 'Erro no servidor (${res.statusCode})');
      }
    } catch (_) {
      setState(() => errorMsg = 'Sem conexão com a internet. Verifique a rede.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openManualLoginDialog() async {
    final titleCtrl = TextEditingController(text: 'Minha Playlist');
    final dnsCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.playlist_add_rounded, color: Color(0xFF6352FF)),
            SizedBox(width: 10),
            Text('Adicionar Playlist (Xtream API)', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Nome da Lista'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dnsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL do Servidor (ex: http://servidor.com:8080)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Usuário'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6352FF)),
            onPressed: () {
              if (dnsCtrl.text.trim().isEmpty ||
                  userCtrl.text.trim().isEmpty ||
                  passCtrl.text.trim().isEmpty) {
                return;
              }
              final customAccount = {
                'title': titleCtrl.text.trim().isEmpty ? 'Minha Playlist' : titleCtrl.text.trim(),
                'dns_url': dnsCtrl.text.trim(),
                'username': userCtrl.text.trim(),
                'password': passCtrl.text.trim(),
              };
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardPage(account: customAccount, macAddress: macAddress),
                ),
              );
            },
            child: const Text('Entrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.3,
            colors: [
              Color(0xFF201C52),
              Color(0xFF0E101C),
              Color(0xFF07080F),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
                    decoration: BoxDecoration(
                      color: const Color(0xEB141726),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x4D6352FF), width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 36,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(size: 70),
                        const SizedBox(height: 12),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            children: [
