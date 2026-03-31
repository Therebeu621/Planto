import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:planto/core/services/gemini_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/garden_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _geminiService = GeminiService();
  final _plantService = PlantService();
  final _gardenService = GardenService();
  final _houseService = HouseService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _messagesKey = 'chat_messages';
  static const _historyKey = 'chat_history';

  final List<_ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = [];
  String _plantsContext = '';
  String _culturesContext = '';
  bool _isLoading = false;
  bool _contextLoaded = false;

  @override
  void initState() {
    super.initState();
    _restoreSession().then((_) => _loadContext());
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getString(_messagesKey);
    final historyJson = prefs.getString(_historyKey);

    if (messagesJson != null) {
      final list = jsonDecode(messagesJson) as List;
      for (final m in list) {
        _messages.add(_ChatMessage(
          text: m['text'],
          isUser: m['isUser'],
          isError: m['isError'] ?? false,
        ));
      }
    }
    if (historyJson != null) {
      final list = jsonDecode(historyJson) as List;
      for (final h in list) {
        _conversationHistory.add(Map<String, String>.from(h));
      }
    }
    if (_messages.isNotEmpty && mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesData = _messages.map((m) => {
      'text': m.text,
      'isUser': m.isUser,
      'isError': m.isError,
    }).toList();
    await prefs.setString(_messagesKey, jsonEncode(messagesData));
    await prefs.setString(_historyKey, jsonEncode(_conversationHistory));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      // Charger les plantes
      final plants = await _plantService.getMyPlants();
      if (plants.isNotEmpty) {
        final buffer = StringBuffer();
        for (final p in plants) {
          buffer.writeln('- ${p.nickname} (${p.speciesCommonName ?? "espece inconnue"})');
          buffer.writeln('  Piece: ${p.roomName ?? "non assignee"}');
          buffer.writeln('  Arrosage: tous les ${p.wateringIntervalDays ?? "?"} jours');
          if (p.needsWatering) buffer.writeln('  *** A ARROSER ***');
          if (p.isSick) buffer.writeln('  *** MALADE ***');
          if (p.isWilted) buffer.writeln('  *** FANEE ***');
          if (p.needsRepotting) buffer.writeln('  *** A REMPOTER ***');
          if (p.exposure != null) buffer.writeln('  Luminosite: ${p.exposureDisplay}');
          if (p.notes != null && p.notes!.isNotEmpty) buffer.writeln('  Notes: ${p.notes}');
          if (p.lastWatered != null) {
            final d = p.lastWatered!;
            buffer.writeln('  Dernier arrosage: ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
          }
          if (p.nextWateringDate != null) {
            final d = p.nextWateringDate!;
            buffer.writeln('  Prochain arrosage: ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
          }
        }
        _plantsContext = buffer.toString();
      }

      // Charger les cultures du potager
      final houses = await _houseService.getMyHouses();
      if (houses.isNotEmpty) {
        final buffer = StringBuffer();
        for (final house in houses) {
          final cultures = await _gardenService.getCultures(house.id);
          for (final c in cultures) {
            buffer.writeln('- ${c['plantName'] ?? '?'} (${c['variety'] ?? 'variete inconnue'})');
            buffer.writeln('  Etape: ${c['statusDisplay'] ?? c['status']}');
            if (c['sowDate'] != null) buffer.writeln('  Date de semis: ${c['sowDate']}');
            if (c['notes'] != null && (c['notes'] as String).isNotEmpty) {
              buffer.writeln('  Notes: ${c['notes']}');
            }
            final logs = c['growthLogs'] as List? ?? [];
            if (logs.isNotEmpty) {
              final lastLog = logs.last;
              if (lastLog['heightCm'] != null) {
                buffer.writeln('  Hauteur: ${lastLog['heightCm']} cm');
              }
              if (lastLog['observations'] != null) {
                buffer.writeln('  Derniere observation: ${lastLog['observations']}');
              }
            }
          }
        }
        _culturesContext = buffer.toString();
      }

      setState(() {
        _contextLoaded = true;
        if (_messages.isEmpty) {
          _messages.add(_ChatMessage(
            text: 'Salut ! Je suis Planto, ton assistant jardinier. '
                'Je connais toutes tes plantes et ton potager. '
                'Pose-moi n\'importe quelle question !',
            isUser: false,
          ));
          _saveSession();
        }
      });
    } catch (e) {
      debugPrint('ChatPage: Erreur chargement contexte - $e');
      setState(() {
        _contextLoaded = true;
        if (_messages.isEmpty) {
          _messages.add(_ChatMessage(
            text: 'Salut ! Je suis Planto, ton assistant jardinier. '
                'Je n\'ai pas pu charger toutes tes donnees, mais je peux quand meme t\'aider !',
            isUser: false,
          ));
          _saveSession();
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _geminiService.chat(
        userMessage: text,
        conversationHistory: _conversationHistory,
        plantsContext: _plantsContext,
        culturesContext: _culturesContext,
      );

      // Ajouter a l'historique
      _conversationHistory.add({'role': 'user', 'text': text});
      _conversationHistory.add({'role': 'model', 'text': response});

      // Garder max 20 messages dans l'historique pour ne pas depasser les limites
      if (_conversationHistory.length > 20) {
        _conversationHistory.removeRange(0, 2);
      }

      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _saveSession();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Oups, une erreur est survenue. Reessaie !',
          isUser: false,
          isError: true,
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Planto IA'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Nouvelle conversation',
            onPressed: () {
              setState(() {
                _messages.clear();
                _conversationHistory.clear();
                _messages.add(_ChatMessage(
                  text: 'Conversation reinitalisee ! Comment puis-je t\'aider ?',
                  isUser: false,
                ));
              });
              _saveSession();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: !_contextLoaded
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                        SizedBox(height: 16),
                        Text('Chargement de tes plantes...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Suggestions rapides
          if (_messages.length <= 1) _buildSuggestions(),

          // Input
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      'Quelles plantes dois-je arroser ?',
      'Comment va mon potager ?',
      'Des conseils pour mes plantes ?',
      'Combien de plantes j\'ai ?',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((s) {
          return ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 12)),
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
            onPressed: () {
              _controller.text = s;
              _sendMessage();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
              child: const Icon(Icons.eco, size: 18, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryColor
                    : message.isError
                        ? AppTheme.errorColor.withOpacity(0.1)
                        : AppTheme.cardBg(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppTheme.textPrimaryC(context),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
              child: const Icon(Icons.person, size: 18, color: AppTheme.primaryColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
            child: const Icon(Icons.eco, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.3 + (0.4 * value)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Pose ta question...',
                hintStyle: TextStyle(color: AppTheme.textSecondaryC(context)),
                filled: true,
                fillColor: AppTheme.lightBg(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _isLoading ? Colors.grey : AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _isLoading ? null : _sendMessage,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}
