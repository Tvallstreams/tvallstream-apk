import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const String kSupabaseUrl = 'https://' 'ihzzgtkavekrvgsxshhy.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_Q5jTnbrCs-dRi4PzrCHohA_wHYqSsYz';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const TvAllStreamApp());
}

class TvAllStreamApp extends StatelessWidget {
  const TvAllStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVAllstream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
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
  String macAddress = '';
  bool loading = false;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateMac();
  }

  Future<void> _loadOrGenerateMac() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('device_mac');
    if (saved == null || saved.isEmpty) {
      final rnd = Random();
      const hex = '0123456789ABCDEF';
      saved = List.generate(6, (_) => '${hex[rnd.nextInt(16)]}${hex[rnd.nextInt(16)]}').join(':');
      await prefs.setString('device_mac', saved);
    }
    setState(() => macAddress = saved!);
  }

  Future<void> _connect() async {
    if (macAddress.isEmpty) return;
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
      body: Center(
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text('SEU ENDEREÇO MAC:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              SelectableText(
                macAddress,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
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
  late final Player player;
  late final VideoController controller;

  String tipoAtual = 'get_live_streams';
  List<dynamic> itens = [];
  bool carregandoLista = true;
  String? selectedId;
  String tituloAtual = '';

  String get dnsUrl => (widget.account['dns_url'] ?? '').toString().replaceAll(RegExp(r'/$'), '');
  String get username => (widget.account['username'] ?? '').toString();
  String get password => (widget.account['password'] ?? '').toString();
  String get accountTitle => (widget.account['title'] ?? 'Usuário').toString();

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _carregarLista('get_live_streams');
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _carregarLista(String action) async {
    setState(() {
      tipoAtual = action;
      carregandoLista = true;
    });

    try {
      final apiUrl = Uri.parse(
        '$dnsUrl/player_api.php?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}&action=$action',
      );
      final res = await http.get(apiUrl);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          setState(() => itens = decoded);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => carregandoLista = false);
    }
  }

  void _tocarItem(Map<String, dynamic> item) {
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
    });

    player.open(Media(streamUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E101A),
        title: Text(accountTitle),
      ),
      body: Row(
        children: [
          SizedBox(
            width: 310,
            child: Column(
              children: [
                _buildTabButton('Aovivo', 'get_live_streams'),
                _buildTabButton('Filmes', 'get_vod_streams'),
                _buildTabButton('Séries', 'get_series'),
                Expanded(
                  child: carregandoLista
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: itens.length,
                          itemBuilder: (context, index) {
                            final item = itens[index] as Map<String, dynamic>;
                            final id = (item['stream_id'] ?? item['series_id'] ?? '').toString();
                            final name = (item['name'] ?? '').toString();
                            final isSelected = id == selectedId;

                            return Container(
                              color: isSelected ? const Color(0xFF5A48F5) : Colors.transparent,
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                                onTap: () => _tocarItem(item),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
