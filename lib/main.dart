import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E101A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5A48F5),
          secondary: Color(0xFF5A48F5),
        ),
      ),
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
          setState(() => errorMsg = 'MAC não registrado ou aguardando ativação.');
        }
      } else {
        setState(() => errorMsg = 'Erro servidor (${res.statusCode})');
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                if (errorMsg != null) ...[
                  Text(
                    errorMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
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
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
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

class PlayerPage extends StatefulWidget {
  final Map<String, dynamic> account;
  const PlayerPage({super.key, required this.account});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _videoController;

  String tipoAtual = 'get_live_streams';
  List<dynamic> itens = [];
  bool carregandoLista = true;
  bool carregandoVideo = false;
  String? selectedId;
  String tituloAtual = '';
  String? erroVideo;
  String? erroLista;

  String get dnsUrl => (widget.account['dns_url'] ?? '').toString().replaceAll(RegExp(r'/$'), '');
  String get username => (widget.account['username'] ?? '').toString();
  String get password => (widget.account['password'] ?? '').toString();
  String get accountTitle => (widget.account['title'] ?? 'Usuário').toString();

  @override
  void initState() {
    super.initState();
    _carregarLista('get_live_streams');
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _carregarLista(String action) async {
    setState(() {
      tipoAtual = action;
      carregandoLista = true;
      erroLista = null;
      itens = [];
    });

    try {
      final apiUrl = Uri.parse(
        '$dnsUrl/player_api.php?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}&action=$action',
      );
      final res = await http.get(
        apiUrl,
        headers: const {
          'User-Agent': 'IPTV Smarters Player',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          setState(() => itens = decoded);
        } else {
          final preview = res.body.length > 80 ? res.body.substring(0, 80) : res.body;
          setState(() => erroLista = 'Resposta inesperada: $preview');
        }
      } else {
        setState(() => erroLista = 'Erro HTTP ${res.statusCode} ao buscar lista');
      }
    } catch (e) {
      setState(() => erroLista = 'Erro de rede: $e');
    } finally {
      if (mounted) setState(() => carregandoLista = false);
    }
  }

  Future<void> _tocarItem(Map<String, dynamic> item) async {
    final id = (item['stream_id'] ?? item['series_id'] ?? '').toString();
    final nome = (item['name'] ?? '').toString();
    final ext = (item['container_extension'] ?? 'mp4').toString();

    String streamUrl = '';
    if (tipoAtual == 'get_live_streams') {
      streamUrl = '$dnsUrl/live/$username/$password/$id.m3u8';
    } else if (tipoAtual == 'get_vod_streams') {
      streamUrl = '$dnsUrl/movie/$username/$password/$id.$ext';
    } else {
      streamUrl = '$dnsUrl/series/$username/$password/$id.$ext';
    }

    setState(() {
      selectedId = id;
      tituloAtual = nome;
      carregandoVideo = true;
      erroVideo = null;
    });

    final oldVideo = _videoController;
    _videoController = null;
    await oldVideo?.dispose();

    try {
      final vc = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: const {'User-Agent': 'IPTV Smarters Player'},
      );
      await vc.initialize();
      await vc.play();
      if (!mounted) {
        await vc.dispose();
        return;
      }
      setState(() {
        _videoController = vc;
        carregandoVideo = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          carregandoVideo = false;
          erroVideo = 'Erro ao abrir stream: $e';
        });
      }
    }
  }

  Widget _buildTabButton(String label, String action) {
    final active = tipoAtual == action;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          onPressed: () => _carregarLista(action),
