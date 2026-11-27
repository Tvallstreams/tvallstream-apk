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
  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
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
  static const _deviceChannel = MethodChannel('com.tvallstream/device');
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

  String _macFromHardwareId(String rawId) {
    final clean = rawId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (clean.length < 12) return '';
    final hex12 = clean.substring(0, 12);
    return List.generate(6, (i) => hex12.substring(i * 2, i * 2 + 2)).join(':');
  }

  String _randomMac() {
    final rnd = Random();
    const hex = '0123456789ABCDEF';
    return List.generate(6, (_) => '${hex[rnd.nextInt(16)]}${hex[rnd.nextInt(16)]}').join(':');
  }

  Future<void> _loadOrGenerateMac() async {
    try {
      final androidId = await _deviceChannel.invokeMethod<String>('getAndroidId');
      if (androidId != null && androidId.isNotEmpty) {
        final fixedMac = _macFromHardwareId(androidId);
        if (fixedMac.isNotEmpty) {
          if (mounted) setState(() => macAddress = fixedMac);
          return;
        }
      }
    } catch (_) {}

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
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Nome da Lista')),
                const SizedBox(height: 10),
                TextField(controller: dnsCtrl, decoration: const InputDecoration(labelText: 'URL do Servidor (ex: http://servidor.com:8080)')),
                const SizedBox(height: 10),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Usuário')),
                const SizedBox(height: 10),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6352FF)),
            onPressed: () {
              if (dnsCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
              final customAccount = {
                'title': titleCtrl.text.trim().isEmpty ? 'Minha Playlist' : titleCtrl.text.trim(),
                'dns_url': dnsCtrl.text.trim(),
                'username': userCtrl.text.trim(),
                'password': passCtrl.text.trim(),
              };
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DashboardPage(account: customAccount, macAddress: macAddress)),
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
            colors: [Color(0xFF201C52), Color(0xFF0E101C), Color(0xFF07080F)],
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
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xEB141726),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x4D6352FF), width: 1.5),
                      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 36, offset: Offset(0, 16))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(size: 104),
                        const SizedBox(height: 10),
                        const Text(
                          'SMART MEDIA & STREAMING PLAYER',
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.2),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0E18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              const Text('ENDEREÇO MAC DO DISPOSITIVO', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                              const SizedBox(height: 4),
class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> account;
  final String macAddress;
  const DashboardPage({super.key, required this.account, required this.macAddress});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int focusedIndex = 0;

  void _openSection(String initialAction) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerPage(account: widget.account, initialAction: initialAction)),
    );
  }

  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151828),
        title: const Text('Informações da Conta', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perfil: ${widget.account['title'] ?? 'Usuário'}'),
            const SizedBox(height: 8),
            Text('MAC do Dispositivo: ${widget.macAddress}'),
            const SizedBox(height: 8),
            const Text('Status: Ativo', style: TextStyle(color: Colors.greenAccent)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }

  Widget _buildMenuCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    final isFocused = focusedIndex == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: InkWell(
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(22),
          onFocusChange: (f) {
            if (f) setState(() => focusedIndex = index);
          },
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isFocused ? Colors.white : Colors.white12, width: isFocused ? 3 : 1),
              boxShadow: isFocused ? [BoxShadow(color: gradient.first.withValues(alpha: 0.55), blurRadius: 24, offset: const Offset(0, 10))] : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                  child: Icon(icon, size: 42, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                const SizedBox(height: 6),
                Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileName = (widget.account['title'] ?? 'Usuário').toString();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14182E), Color(0xFF0B0D17)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    const AppLogo(size: 46),
                    const SizedBox(width: 14),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        children: [
                          TextSpan(text: 'TvAll', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Stream', style: TextStyle(color: Color(0xFF7B61FF))),
                          TextSpan(text: ' TV', style: TextStyle(color: Color(0xFF00D2FF))),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF181C33), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle_rounded, color: Color(0xFF00D2FF), size: 20),
                          const SizedBox(width: 8),
                          Text(profileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(tooltip: 'Minha Conta', icon: const Icon(Icons.info_outline_rounded, color: Colors.white70), onPressed: _showAccountDialog),
                    IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout_rounded, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    children: [
                      _buildMenuCard(
                        index: 0,
                        autofocus: true,
                        title: 'TV AO VIVO',
                        subtitle: 'Canais esportivos, notícias e abertos',
                        icon: Icons.live_tv_rounded,
                        gradient: const [Color(0xFF6352FF), Color(0xFF392B9E)],
                        onTap: () => _openSection('get_live_streams'),
                      ),
                      _buildMenuCard(
                        index: 1,
                        title: 'FILMES',
                        subtitle: 'Catálogo completo sob demanda',
                        icon: Icons.movie_creation_rounded,
                        gradient: const [Color(0xFF0099CC), Color(0xFF004E7C)],
                        onTap: () => _openSection('get_vod_streams'),
                      ),
                      _buildMenuCard(
                        index: 2,
                        title: 'SÉRIES',
                        subtitle: 'Temporadas e episódios organizados',
                        icon: Icons.video_library_rounded,
                        gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                        onTap: () => _openSection('get_series'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MAC: ${widget.macAddress}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const Text('Use as setas do controle remoto e OK para navegar', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
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
  final String initialAction;
  const PlayerPage({super.key, required this.account, this.initialAction = 'get_live_streams'});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _videoController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _osdTimer;

  late String tipoAtual;
  List<dynamic> categorias = [];
  String categoriaSelecionada = 'ALL';
  List<dynamic> itens = [];
  String filtroBusca = '';

  bool carregandoLista = true;
  bool carregandoVideo = false;
  bool isFullScreen = false;
  bool showOsd = true;

  String? selectedId;
  String tituloAtual = '';
  String? erroVideo;
  String? erroLista;

  String get dnsUrl => (widget.account['dns_url'] ?? '').toString().replaceAll(RegExp(r'/$'), '');
  String get username => (widget.account['username'] ?? '').toString();
  String get password => (widget.account['password'] ?? '').toString();

  Map<String, String> get _headers => const {'User-Agent': 'IPTV Smarters Player', 'Accept': 'application/json'};

  List<dynamic> get itensFiltrados {
    return itens.where((raw) {
      final item = raw as Map<String, dynamic>;
      if (categoriaSelecionada != 'ALL' && (item['category_id'] ?? '').toString() != categoriaSelecionada) return false;
      if (filtroBusca.isNotEmpty && !(item['name'] ?? '').toString().toLowerCase().contains(filtroBusca.toLowerCase())) return false;
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    tipoAtual = widget.initialAction;
    _carregarSecao(tipoAtual);
  }

  @override
  void dispose() {
    _osdTimer?.cancel();
    _searchController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _triggerOsd() {
    setState(() => showOsd = true);
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && isFullScreen) setState(() => showOsd = false);
    });
  }

