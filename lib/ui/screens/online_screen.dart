import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reinos_engine/game_engine/domain/player_color.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';
import '../design_system/tokens.dart';
import '../game_controller.dart';
import 'game_screen.dart';

/// Fixed seat ids for the online MVP (2 human players only — section
/// 36/37 ships the server-authoritative core first; more seats/bots in
/// online rooms is follow-up work). The host is always `p0`, the one
/// joining by room code is always `p1`.
const _hostPlayerId = 'p0';
const _guestPlayerId = 'p1';
const _defaultMapId = 'biblical_lands_v1';

/// Entry point for section 36 ("Online com amigos / ranqueada"): pick
/// whether this device is creating a new room or joining one by code.
class OnlineScreen extends StatelessWidget {
  const OnlineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JOGAR ONLINE')),
      backgroundColor: ReinosColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ReinosSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Jogue em tempo real com outro jogador, cada um no seu '
                'próprio aparelho.',
                style: ReinosTypography.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ReinosSpacing.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ReinosColors.gold,
                  foregroundColor: ReinosColors.background,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                ),
                child: const Text('CRIAR SALA'),
              ),
              const SizedBox(height: ReinosSpacing.md),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                ),
                child: const Text('ENTRAR COM CÓDIGO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hosts a new room: connects, creates it with both seats already
/// defined, and waits for the guest to connect before the match can
/// start (the guest's `GameScreen` opens the moment it joins; the host's
/// opens here as soon as [onPlayerConnected] fires).
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _serverUrlController = TextEditingController();
  final _nameController = TextEditingController(text: 'Jogador 1');
  bool _connecting = false;
  String? _roomCode;
  String? _error;

  @override
  void dispose() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.onPlayerConnected = null;
    _serverUrlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final serverUrl = _serverUrlController.text.trim();
    if (serverUrl.isEmpty) {
      setState(() => _error = 'Informe o endereço do servidor.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    final controller = ref.read(gameControllerProvider.notifier);
    controller.onPlayerConnected = (playerId) {
      if (playerId == _guestPlayerId && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
    };

    try {
      await controller.createOnlineRoom(
        serverUrl: serverUrl,
        mapId: _defaultMapId,
        hostPlayerId: _hostPlayerId,
        seed: DateTime.now().millisecondsSinceEpoch,
        players: [
          PlayerConfig(
            id: _hostPlayerId,
            displayName: _nameController.text.trim().isEmpty
                ? 'Jogador 1'
                : _nameController.text.trim(),
            color: PlayerColor.blue,
          ),
          const PlayerConfig(
            id: _guestPlayerId,
            displayName: 'Jogador 2',
            color: PlayerColor.red,
          ),
        ],
      );
      if (!mounted) return;
      setState(() {
        _roomCode = controller.roomCode;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível conectar ao servidor: $e';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = _roomCode;
    return Scaffold(
      appBar: AppBar(title: const Text('CRIAR SALA')),
      backgroundColor: ReinosColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ReinosSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: roomCode == null
                ? [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Seu nome'),
                    ),
                    const SizedBox(height: ReinosSpacing.md),
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Endereço do servidor (ws://...)',
                        hintText: 'wss://reinos-server.fly.dev',
                      ),
                    ),
                    const SizedBox(height: ReinosSpacing.lg),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: ReinosColors.danger)),
                      const SizedBox(height: ReinosSpacing.md),
                    ],
                    FilledButton(
                      onPressed: _connecting ? null : _createRoom,
                      child: _connecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('CRIAR'),
                    ),
                  ]
                : [
                    Text('CÓDIGO DA SALA', style: ReinosTypography.label),
                    const SizedBox(height: ReinosSpacing.sm),
                    Text(roomCode, style: ReinosTypography.title),
                    const SizedBox(height: ReinosSpacing.xl),
                    const CircularProgressIndicator(),
                    const SizedBox(height: ReinosSpacing.md),
                    Text(
                      'Aguardando o outro jogador entrar com esse código...',
                      style: ReinosTypography.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

/// Joins an existing room by code, always taking the guest seat.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _serverUrlController = TextEditingController();
  final _roomCodeController = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final serverUrl = _serverUrlController.text.trim();
    final roomCode = _roomCodeController.text.trim();
    if (serverUrl.isEmpty || roomCode.isEmpty) {
      setState(() => _error = 'Informe o servidor e o código da sala.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    final controller = ref.read(gameControllerProvider.notifier);
    try {
      await controller.joinOnlineRoom(
        serverUrl: serverUrl,
        roomCode: roomCode,
        playerId: _guestPlayerId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível entrar na sala: $e';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ENTRAR COM CÓDIGO')),
      backgroundColor: ReinosColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ReinosSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Endereço do servidor (ws://...)',
                  hintText: 'wss://reinos-server.fly.dev',
                ),
              ),
              const SizedBox(height: ReinosSpacing.md),
              TextField(
                controller: _roomCodeController,
                decoration: const InputDecoration(labelText: 'Código da sala'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: ReinosSpacing.lg),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: ReinosColors.danger)),
                const SizedBox(height: ReinosSpacing.md),
              ],
              FilledButton(
                onPressed: _connecting ? null : _joinRoom,
                child: _connecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ENTRAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
