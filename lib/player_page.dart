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
