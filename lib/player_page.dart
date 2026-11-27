import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class PlayerPage extends StatefulWidget {
  final Map<String, dynamic> account;
  const PlayerPage({super.key, required this.account});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _vc;
  String tipo = 'get_live_streams';
  List<dynamic> itens = [];
  bool loadingList = true;
  bool loadingVid = false;
  String? selId;
  String titulo = '';
  String? erro;

  String get dns => (widget.account['dns_url'] ?? '').toString().replaceAll(RegExp(r'/$'), '');
  String get user => (widget.account['username'] ?? '').toString();
  String get pass => (widget.account['password'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load('get_live_streams');
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _load(String action) async {
    setState(() {
      tipo = action;
      loadingList = true;
    });
    try {
      final res = await http.get(Uri.parse('$dns/player_api.php?username=$user&password=$pass&action=$action'));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is List) setState(() => itens = d);
      }
    } catch (_) {}
    if (mounted) setState(() => loadingList = false);
  }

  Future<void> _play(Map<String, dynamic> item) async {
    final id = (item['stream_id'] ?? item['series_id'] ?? '').toString();
    final ext = (item['container_extension'] ?? 'mp4').toString();
    final url = tipo == 'get_live_streams'
        ? '$dns/live/$user/$pass/$id.m3u8'
        : tipo == 'get_vod_streams'
            ? '$dns/movie/$user/$pass/$id.$ext'
            : '$dns/series/$user/$pass/$id.$ext';

    setState(() {
      selId = id;
      titulo = (item['name'] ?? '').toString();
      loadingVid = true;
      erro = null;
    });

    final old = _vc;
    _vc = null;
    await old?.dispose();

    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: const {'User-Agent': 'IPTV Smarters Player'});
      await c.initialize();
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _vc = c;
        loadingVid = false;
      });
    } catch (e) {
      if (mounted) setState(() { loadingVid = false; erro = 'Erro: $e'; });
    }
  }

  Widget _tab(String label, String act) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: tipo == act ? const Color(0xFF5A48F5) : const Color(0xFF282266),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _load(act),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E101A),
      appBar: AppBar(backgroundColor: const Color(0xFF0E101A), title: Text((widget.account['title'] ?? 'TVAllstream').toString())),
      body: Row(
        children: [
          SizedBox(
            width: 300,
            child: Column(
              children: [
                _tab('Aovivo', 'get_live_streams'),
                _tab('Filmes', 'get_vod_streams'),
                _tab('Séries', 'get_series'),
                Expanded(
                  child: loadingList
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: itens.length,
                          itemBuilder: (_, i) {
                            final it = itens[i] as Map<String, dynamic>;
                            final id = (it['stream_id'] ?? it['series_id'] ?? '').toString();
                            return Container(
                              color: id == selId ? const Color(0xFF5A48F5) : Colors.transparent,
                              child: ListTile(
                                dense: true,
                                title: Text((it['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () => _play(it),
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
              child: Center(
                child: loadingVid
                    ? const CircularProgressIndicator()
                    : erro != null
                        ? Text(erro!, style: const TextStyle(color: Colors.redAccent))
                        : (_vc != null && _vc!.value.isInitialized)
                            ? AspectRatio(aspectRatio: _vc!.value.aspectRatio > 0 ? _vc!.value.aspectRatio : 16 / 9, child: VideoPlayer(_vc!))
                            : const Text('Selecione um canal ao lado', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
