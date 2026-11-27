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
