import 'package:flutter/material.dart';
import 'main.dart';
import 'player_page.dart';

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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
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
