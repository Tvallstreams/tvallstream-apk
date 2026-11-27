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
                              TextSpan(text: 'TvAll', style: TextStyle(color: Colors.white)),
                              TextSpan(text: 'Stream', style: TextStyle(color: Color(0xFF7B61FF))),
                              TextSpan(text: ' TV', style: TextStyle(color: Color(0xFF00D2FF))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SMART MEDIA & STREAMING PLAYER',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 20),
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
                              const Text(
                                'ENDEREÇO MAC DO DISPOSITIVO',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                macAddress,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (errorMsg != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              errorMsg!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  autofocus: true,
                                  onFocusChange: (f) => setState(() => connectFocused = f),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6352FF),
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: connectFocused ? Colors.white : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: loading ? null : _connectWithMac,
                                  child: loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.play_circle_fill_rounded, size: 22),
                                            SizedBox(width: 8),
                                            Text(
                                              'CONECTAR',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  onFocusChange: (f) => setState(() => manualFocused = f),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFF1A1E33),
                                    side: BorderSide(
                                      color: manualFocused ? Colors.white : Colors.white24,
                                      width: manualFocused ? 2.5 : 1,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: loading ? null : _openManualLoginDialog,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.playlist_add_rounded, size: 20),
                                      SizedBox(width: 6),
                                      Text(
                                        'PLAYLIST',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'TvAllStream TV é exclusivamente um reprodutor de mídia e não fornece nem inclui canais, filmes ou assinaturas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
      MaterialPageRoute(
        builder: (_) => PlayerPage(account: widget.account, initialAction: initialAction),
      ),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isFocused ? Colors.white : Colors.white12,
                width: isFocused ? 3 : 1,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.55),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 42, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF14182E), Color(0xFF0B0D17)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    const AppLogo(size: 44),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFF181C33),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle_rounded, color: Color(0xFF00D2FF), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            profileName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Minha Conta',
                      icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                      onPressed: _showAccountDialog,
                    ),
                    IconButton(
                      tooltip: 'Sair',
                      icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
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
                    Text(
                      'MAC: ${widget.macAddress}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const Text(
                      'Use as setas do controle remoto e OK para navegar',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
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
  const PlayerPage({
    super.key,
    required this.account,
    this.initialAction = 'get_live_streams',
  });

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

  Map<String, String> get _headers => const {
        'User-Agent': 'IPTV Smarters Player',
        'Accept': 'application/json',
      };

  List<dynamic> get itensFiltrados {
    return itens.where((raw) {
      final item = raw as Map<String, dynamic>;
      if (categoriaSelecionada != 'ALL') {
        final catId = (item['category_id'] ?? '').toString();
        if (catId != categoriaSelecionada) return false;
      }
      if (filtroBusca.isNotEmpty) {
        final nome = (item['name'] ?? '').toString().toLowerCase();
        if (!nome.contains(filtroBusca.toLowerCase())) return false;
      }
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
      if (mounted && isFullScreen) {
        setState(() => showOsd = false);
      }
    });
  }

  void _entrarTelaCheia() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    setState(() => isFullScreen = true);
    _triggerOsd();
  }

  void _sairTelaCheia() {
    _osdTimer?.cancel();
    setState(() {
      isFullScreen = false;
      showOsd = true;
    });
  }

  String _categoryActionFor(String streamAction) {
    if (streamAction == 'get_vod_streams') return 'get_vod_categories';
    if (streamAction == 'get_series') return 'get_series_categories';
    return 'get_live_categories';
  }

  Future<void> _carregarSecao(String action) async {
    setState(() {
      tipoAtual = action;
      carregandoLista = true;
      erroLista = null;
      categorias = [];
      categoriaSelecionada = 'ALL';
      itens = [];
      filtroBusca = '';
      _searchController.clear();
    });

    try {
      final catAction = _categoryActionFor(action);
      final catUrl = Uri.parse(
        '$dnsUrl/player_api.php?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}&action=$catAction',
      );
      final streamUrl = Uri.parse(
        '$dnsUrl/player_api.php?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}&action=$action',
      );

      final results = await Future.wait([
        http.get(catUrl, headers: _headers),
        http.get(streamUrl, headers: _headers),
      ]);

      final catRes = results.first;
      final listRes = results.last;

      if (catRes.statusCode == 200) {
        final decodedCats = jsonDecode(catRes.body);
        if (decodedCats is List) {
          categorias = decodedCats;
        }
      }

      if (listRes.statusCode == 200) {
        final decoded = jsonDecode(listRes.body);
        if (decoded is List) {
          setState(() => itens = decoded);
        } else {
          setState(() => erroLista = 'Resposta inesperada do servidor');
        }
      } else {
        setState(() => erroLista = 'Erro HTTP ${listRes.statusCode} ao buscar lista');
      }
    } catch (e) {
      setState(() => erroLista = 'Erro de rede: $e');
    } finally {
      if (mounted) setState(() => carregandoLista = false);
    }
  }

  Future<void> _abrirSerie(Map<String, dynamic> serie) async {
    final seriesId = (serie['series_id'] ?? '').toString();
    final nomeSerie = (serie['name'] ?? 'Série').toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = Uri.parse(
        '$dnsUrl/player_api.php?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}&action=get_series_info&series_id=$seriesId',
      );
      final res = await http.get(url, headers: _headers);
      if (!mounted) return;
      Navigator.pop(context);

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final episodesMap = (data is Map && data['episodes'] is Map)
          ? data['episodes'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (episodesMap.isEmpty) return;

      final seasons = episodesMap.keys.toList();
      String selectedSeason = seasons.first;

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              final epList = (episodesMap[selectedSeason] as List?) ?? [];
              return AlertDialog(
                backgroundColor: const Color(0xFF151828),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        nomeSerie,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: selectedSeason,
                      dropdownColor: const Color(0xFF23273D),
                      items: seasons
                          .map((s) => DropdownMenuItem(value: s, child: Text('Temporada $s')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedSeason = val);
                      },
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 520,
                  height: 320,
                  child: ListView.builder(
                    itemCount: epList.length,
                    itemBuilder: (_, idx) {
                      final ep = epList[idx] as Map<String, dynamic>;
                      final epNum = (ep['episode_num'] ?? (idx + 1)).toString();
                      final epTitle = (ep['title'] ?? 'Episódio $epNum').toString();
                      final epId = (ep['id'] ?? '').toString();
                      final ext = (ep['container_extension'] ?? 'mp4').toString();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6352FF),
                          child: Text(epNum, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        title: Text(epTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          Navigator.pop(ctx);
                          _reproduzirUrl(
                            id: seriesId,
                            nome: '$nomeSerie - T$selectedSeason:E$epNum',
                            streamUrl: '$dnsUrl/series/$username/$password/$epId.$ext',
                          );
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fechar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _tocarItem(Map<String, dynamic> item) async {
    if (tipoAtual == 'get_series') {
      await _abrirSerie(item);
      return;
    }

    final id = (item['stream_id'] ?? '').toString();
    final nome = (item['name'] ?? '').toString();
    final ext = (item['container_extension'] ?? 'mp4').toString();

    if (selectedId == id && _videoController != null && _videoController!.value.isInitialized) {
      _entrarTelaCheia();
      return;
    }

    final streamUrl = tipoAtual == 'get_live_streams'
        ? '$dnsUrl/live/$username/$password/$id.m3u8'
        : '$dnsUrl/movie/$username/$password/$id.$ext';

    await _reproduzirUrl(id: id, nome: nome, streamUrl: streamUrl);
  }

  Future<void> _reproduzirUrl({
    required String id,
    required String nome,
    required String streamUrl,
  }) async {
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
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          height: 36,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: active ? const Color(0xFF6352FF) : const Color(0xFF232742),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _carregarSecao(action),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    final vc = _videoController;
    return GestureDetector(
      onTap: () {
        if (isFullScreen) {
          _triggerOsd();
        } else if (vc != null && vc.value.isInitialized) {
          _entrarTelaCheia();
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Center(
              child: carregandoVideo
                  ? const CircularProgressIndicator()
                  : erroVideo != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(erroVideo!, style: const TextStyle(color: Colors.redAccent)),
                        )
                      : (vc != null && vc.value.isInitialized)
                          ? AspectRatio(
                              aspectRatio: vc.value.aspectRatio > 0 ? vc.value.aspectRatio : 16 / 9,
                              child: VideoPlayer(vc),
                            )
                          : const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.ondemand_video_rounded, size: 54, color: Colors.white24),
                                SizedBox(height: 10),
                                Text(
                                  'Selecione um título ao lado para iniciar',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
            ),
            if (vc != null && vc.value.isInitialized && (!isFullScreen || showOsd))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: const Color(0xCC141726),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(vc.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            vc.value.isPlaying ? vc.pause() : vc.play();
                          });
                          if (isFullScreen) _triggerOsd();
                        },
                      ),
                      Expanded(
                        child: Text(
                          tituloAtual,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: isFullScreen ? 'Sair da tela cheia' : 'Tela cheia',
                        icon: Icon(
                          isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          if (isFullScreen) {
                            _sairTelaCheia();
                          } else {
                            _entrarTelaCheia();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = itensFiltrados;

    return PopScope(
      canPop: !isFullScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isFullScreen) {
          _sairTelaCheia();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D17),
        body: isFullScreen
            ? _buildVideoArea()
            : Row(
                children: [
                  Container(
                    width: 345,
                    color: const Color(0xFF121524),
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 22),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            const AppLogo(size: 26),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'TvAllStream (${lista.length})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildTabButton('Ao Vivo', 'get_live_streams'),
                            _buildTabButton('Filmes', 'get_vod_streams'),
                            _buildTabButton('Séries', 'get_series'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (categorias.isNotEmpty)
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1E33),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: categoriaSelecionada,
                                dropdownColor: const Color(0xFF1A1E33),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'ALL',
                                    child: Text('Todas as Categorias'),
                                  ),
                                  ...categorias.map((c) {
                                    final map = c as Map<String, dynamic>;
                                    final cId = (map['category_id'] ?? '').toString();
                                    final cName = (map['category_name'] ?? '').toString();
                                    return DropdownMenuItem(
                                      value: cId,
                                      child: Text(cName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => categoriaSelecionada = val);
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Buscar canal, filme ou série...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                              suffixIcon: filtroBusca.isNotEmpty
                                  ? IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => filtroBusca = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFF1A1E33),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) => setState(() => filtroBusca = val),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: carregandoLista
                              ? const Center(child: CircularProgressIndicator())
                              : erroLista != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        erroLista!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: lista.length,
                                      itemBuilder: (context, index) {
                                        final item = lista[index] as Map<String, dynamic>;
                                        final id = (item['stream_id'] ?? item['series_id'] ?? '').toString();
                                        final name = (item['name'] ?? '').toString();
                                        final isSelected = id == selectedId;

                                        return Container(
                                          margin: const EdgeInsets.symmetric(vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF6352FF) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            visualDensity: const VisualDensity(vertical: -2),
                                            title: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            trailing: Icon(
                                              isSelected ? Icons.fullscreen : Icons.chevron_right,
                                              color: Colors.white70,
                                              size: 18,
                                            ),
                                            onTap: () => _tocarItem(item),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildVideoArea()),
                ],
              ),
      ),
    );
  }
}
