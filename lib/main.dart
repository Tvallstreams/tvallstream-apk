  @override
  Widget build(BuildContext context) {
    final vc = _videoController;
    return Scaffold(
      backgroundColor: const Color(0xFF0E101A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E101A),
        title: Text(accountTitle, style: const TextStyle(color: Colors.white)),
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
              child: Column(
                children: [
                  Expanded(
                    child: Center(
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
                                  : const Text(
                                      'Selecione um canal ou filme ao lado',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                    ),
                  ),
                  if (vc != null && vc.value.isInitialized)
                    Container(
                      color: const Color(0xFF171A29),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(vc.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                vc.value.isPlaying ? vc.pause() : vc.play();
                              });
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
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
