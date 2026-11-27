import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'main.dart';

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

  String get dnsUrl =>
      (widget.account['dns_url'] ?? '').toString().replaceAll(RegExp(r'/$'), '');
  String get username => (widget.account['username'] ?? '').toString();
  String get password => (widget.account['password'] ?? '').toString();

  Map<String, String> get _headers => const {
        'User-Agent': 'IPTV Smarters Player',
        'Accept': 'application/json',
      };

  List<dynamic> get itensFiltrados {
    return itens.where((raw) {
      final item = raw as Map<String, dynamic>;
      if (categoriaSelecionada != 'ALL' &&
          (item['category_id'] ?? '').toString() != categoriaSelecionada) {
        return false;
      }
      if (filtroBusca.isNotEmpty &&
          !(item['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(filtroBusca.toLowerCase())) {
        return false;
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
      if (mounted && isFullScreen) setState(() => showOsd = false);
    });
  }

  void _entrarTelaCheia() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
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
      if (results.first.statusCode == 200) {
        final decodedCats = jsonDecode(results.first.body);
        if (decodedCats is List) categorias = decodedCats;
      }
      if (results.last.statusCode == 200) {
        final decoded = jsonDecode(results.last.body);
        if (decoded is List) {
          setState(() => itens = decoded);
        } else {
          setState(() => erroLista = 'Resposta inesperada do servidor');
        }
      } else {
        setState(
          () => erroLista = 'Erro HTTP ${results.last.statusCode} ao buscar lista',
        );
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
        builder: (ctx) => StatefulBuilder(
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
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text('Temporada $s'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedSeason = val);
                      }
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
                    final epTitle =
                        (ep['title'] ?? 'Episódio $epNum').toString();
                    final epId = (ep['id'] ?? '').toString();
                    final ext = (ep['container_extension'] ?? 'mp4').toString();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6352FF),
                        child: Text(
                          epNum,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        epTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _reproduzirUrl(
                          id: seriesId,
                          nome: '$nomeSerie - T$selectedSeason:E$epNum',
                          streamUrl:
                              '$dnsUrl/series/$username/$password/$epId.$ext',
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
        ),
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
    if (selectedId == id &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
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
      final vc = VideoPlayerController.networkUrl(Uri.parse(streamUrl), httpHeaders: const {'User-Agent': 'IPTV Smarters Player'});
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
                      ? Padding(padding: const EdgeInsets.all(16), child: Text(erroVideo!, style: const TextStyle(color: Colors.redAccent)))
                      : (vc != null && vc.value.isInitialized)
                          ? AspectRatio(aspectRatio: vc.value.aspectRatio > 0 ? vc.value.aspectRatio : 16 / 9, child: VideoPlayer(vc))
                          : const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.ondemand_video_rounded, size: 54, color: Colors.white24),
                                SizedBox(height: 10),
                                Text('Selecione um título ao lado para iniciar', style: TextStyle(color: Colors.white54)),
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
                          setState(() => vc.value.isPlaying ? vc.pause() : vc.play());
                          if (isFullScreen) _triggerOsd();
                        },
                      ),
                      Expanded(child: Text(tituloAtual, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      IconButton(
                        tooltip: isFullScreen ? 'Sair da tela cheia' : 'Tela cheia',
                        icon: Icon(isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 28),
                        onPressed: () => isFullScreen ? _sairTelaCheia() : _entrarTelaCheia(),
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
        if (!didPop && isFullScreen) _sairTelaCheia();
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
                            IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 22), onPressed: () => Navigator.pop(context)),
                            const SizedBox(width: 8),
                            const AppLogo(size: 26),
                            const SizedBox(width: 8),
                            Expanded(child: Text('TvAllStream (${lista.length})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
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
                            decoration: BoxDecoration(color: const Color(0xFF1A1E33), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: categoriaSelecionada,
                                dropdownColor: const Color(0xFF1A1E33),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                items: [
                                  const DropdownMenuItem(value: 'ALL', child: Text('Todas as Categorias')),
                                  ...categorias.map((c) {
                                    final map = c as Map<String, dynamic>;
                                    return DropdownMenuItem(value: (map['category_id'] ?? '').toString(), child: Text((map['category_name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis));
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                            onChanged: (val) => setState(() => filtroBusca = val),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: carregandoLista
                              ? const Center(child: CircularProgressIndicator())
                              : erroLista != null
                                  ? Padding(padding: const EdgeInsets.all(12), child: Text(erroLista!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)))
