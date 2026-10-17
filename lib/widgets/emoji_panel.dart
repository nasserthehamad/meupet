import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Painel de emojis do chat (como no WhatsApp): abre no lugar do teclado.
class EmojiPanel extends StatelessWidget {
  final ValueChanged<String> onPick;
  final VoidCallback onBackspace;
  final double height;
  const EmojiPanel({super.key, required this.onPick, required this.onBackspace, this.height = 270});

  static const groups = <(String, String)>[
    ('😀', '😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 😉 😍 🥰 😘 😋 😛 😜 🤪 😎 🤩 🥳 😏 😌 😴 🤔 🤗 🤭 😮 😲 😳 🥺 '
        '😢 😭 😤 😠 😡 😱 😨 😰 😓 🤒 🤕 🤢 🤧 😷 🙄 😬 😶 😐 😑 🙃 🤓 🧐 😺 😸 😹 😻 😽 🙀 😿'),
    ('🐾', '🐶 🐕 🦮 🐩 🐱 🐈 🐰 🐇 🐹 🐭 🐁 🐀 🐿️ 🦔 🐢 🦎 🐍 🐦 🐤 🐥 🦜 🦉 🐔 🦆 🐠 🐟 🐡 🐴 🐷 🐮 '
        '🐑 🐐 🦙 🐾 🦴 🧶 🎾 🥎 🍖 🥩 🥕 🍎 🐝 🦋 🐞 🌿 🌳 🏡'),
    ('❤️', '❤️ 🧡 💛 💚 💙 💜 🤎 🖤 🤍 💕 💞 💓 💗 💖 💘 💝 💟 ❣️ 💔 💋 🌹 🌷 🌸 🌻 🌼 ✨ ⭐ 🌟 🎉 🎊 🎁 🎂 🎈 🏆'),
    ('👍', '👍 👎 👌 ✌️ 🤞 🤟 🤙 👋 🙌 👏 🙏 🤝 💪 👊 ✊ 🤲 👐 ☝️ 👆 👇 👉 👈 ✋ 🤚 🖐️ 👀 🧠'),
    ('🩺', '🩺 💉 💊 🩹 🌡️ 🏥 🚑 🚕 🚗 🛁 🧼 🧴 🪥 ✂️ 🛒 🛍️ 📦 📅 ⏰ ⏳ 📍 🏠 📞 💬 📷 📄 ✅ ❌ ⚠️ ❗ ❓ 💤 ☀️ 🌧️ ❄️ 💰'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: AppColors.surface,
      child: DefaultTabController(
        length: groups.length,
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TabBar(
                isScrollable: false,
                indicatorColor: AppColors.teal,
                dividerColor: AppColors.line,
                labelPadding: EdgeInsets.zero,
                tabs: [for (final g in groups) Tab(height: 42, child: Text(g.$1, style: const TextStyle(fontSize: 22)))],
              ),
            ),
            IconButton(
              key: const Key('emoji_apagar'),
              tooltip: 'Apagar',
              onPressed: onBackspace,
              icon: Icon(Icons.backspace_outlined, color: AppColors.text2),
            ),
          ]),
          Expanded(
            child: TabBarView(children: [
              for (final g in groups)
                LayoutBuilder(builder: (context, c) {
                  final items = g.$2.split(' ').where((e) => e.isNotEmpty).toList();
                  final cols = (c.maxWidth / 46).floor().clamp(6, 12);
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols),
                    itemCount: items.length,
                    itemBuilder: (context, i) => InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onPick(items[i]),
                      child: Center(child: Text(items[i], style: const TextStyle(fontSize: 28))),
                    ),
                  );
                }),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Insere o emoji onde está o cursor.
void insertAtCursor(TextEditingController c, String s) {
  final t = c.text;
  final sel = c.selection;
  final start = sel.isValid ? sel.start : t.length;
  final end = sel.isValid ? sel.end : t.length;
  c.value = TextEditingValue(text: t.replaceRange(start, end, s), selection: TextSelection.collapsed(offset: start + s.length));
}

/// Apaga o caractere (ou emoji inteiro) antes do cursor.
void backspaceAtCursor(TextEditingController c) {
  final t = c.text;
  final sel = c.selection;
  final end = sel.isValid ? sel.end : t.length;
  final start = sel.isValid ? sel.start : t.length;
  if (start != end) {
    c.value = TextEditingValue(text: t.replaceRange(start, end, ''), selection: TextSelection.collapsed(offset: start));
    return;
  }
  if (end == 0) return;
  final before = t.substring(0, end).characters;
  final kept = before.skipLast(1).toString();
  c.value = TextEditingValue(text: kept + t.substring(end), selection: TextSelection.collapsed(offset: kept.length));
}

final _onlyEmoji = RegExp(r'^(?:\p{Extended_Pictographic}|\p{Emoji_Modifier}|‍|️|\s)+$', unicode: true);

/// Mensagem só com 1 a 3 emojis (mostrada grande, como no WhatsApp).
bool isBigEmoji(String text) {
  final t = text.trim();
  if (t.isEmpty || !_onlyEmoji.hasMatch(t)) return false;
  return t.characters.where((g) => g.trim().isNotEmpty).length <= 3;
}
