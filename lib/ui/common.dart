import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/app_state.dart';

/// Цвета бренда: тёмно-синий, янтарный, зелёный и красный для статусов.
/// Цвета в стиле продуктов Контура (дизайн-система Kontur UI, пакет @skbkontur/colors).
class Brand {
  /// Основной цвет действий: кнопки, выбранная вкладка (shapeBoldAccent).
  static const accent = Color(0xFF3D3D3D);
  static const accentDark = Color(0xFFF2F2F2);

  /// Фирменный красный — только знак и логотип (shapeBoldBrandOriginal).
  static const red = Color(0xFFFE4C4C);

  /// Статусы для текста и значков: читаются и на светлом, и на тёмном фоне.
  static const ok = Color(0xFF1C8A3F);
  static const bad = Color(0xFFCC2626);
  static const warning = Color(0xFFD26E00);

  /// Заливки статусов: шкалы и метки (shapeBoldSuccess / Error / Warning).
  static const okFill = Color(0xFF00A948);
  static const badFill = Color(0xFFF63B40);
  static const warningFill = Color(0xFFFFBE3D);

  /// Фон и поверхности (surfaceLow / surfaceHigh), светлая и тёмная тема.
  static const background = Color(0xFFF2F2F2);
  static const backgroundDark = Color(0xFF1F1F1F);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF333333);
  static const headerDark = Color(0xFF292929);

  /// Текст (textNeutralHeavy) и тонкие линии (lineNeutralFaint).
  static const text = Color(0xE0000000);
  static const textDark = Color(0xF5FFFFFF);
  static const line = Color(0x14000000);
  static const lineDark = Color(0x14FFFFFF);
}

/// Сообщение внизу экрана.
void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Brand.badFill : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Выполняет действие и показывает ошибку, если оно не удалось. Возвращает true при успехе.
Future<bool> guarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) toast(context, e is ApiException ? e.message : '$e', error: true);
    return false;
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, AppScope.read(context).tr('common.copied'));
}

Future<bool> confirm(BuildContext context, String question) async {
  final tr = AppScope.read(context).tr;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('✕')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('common.delete'))),
      ],
    ),
  );
  return ok ?? false;
}

/// Загружает данные и строит экран. Перезагружается при смене года, языка или данных.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});

  final Future<T> Function(AppState state) load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  Future<T>? _future;
  Object? _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    final key = (s.year, s.revision, s.tr.lang, s.reportPeriod);
    if (key != _key) {
      _key = key;
      _future = widget.load(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(e is ApiException ? e.message : '$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _future = widget.load(AppScope.read(context))),
                  child: const Icon(Icons.refresh),
                ),
              ]),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

/// Прокручиваемая страница с полями по краям и ограничением ширины на больших экранах.
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children, this.title, this.subtitle, this.actions = const []});

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(title!, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 16),
                child: Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
              ),
            ...children,
          ]),
        ),
      ),
    );
  }
}

/// Карточка-секция.
class Section extends StatelessWidget {
  const Section({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ...children,
        ]),
      ),
    );
  }
}

/// Плашка-предупреждение. bad — красная.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.bad = false, this.onTap});

  final String text;
  final bool bad;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = bad ? Brand.bad : Brand.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            border: Border(left: BorderSide(color: color, width: 4)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

/// Сетка карточек: число колонок зависит от ширины.
class Grid extends StatelessWidget {
  const Grid({super.key, required this.children, this.minWidth = 220});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minWidth).floor().clamp(1, children.length);
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Поля формы в ряд на широком экране и столбиком на узком.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.children, this.minWidth = 180});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Grid(minWidth: minWidth, children: children),
      );
}

InputDecoration field(String label, {String? hint, String? helper}) =>
    InputDecoration(labelText: label, hintText: hint, helperText: helper, helperMaxLines: 3, border: const OutlineInputBorder());

/// Выпадающий список значений.
Widget dropdown<T>({
  required String label,
  required T value,
  required List<T> values,
  required String Function(T) text,
  required ValueChanged<T?> onChanged,
  Key? key,
}) {
  return DropdownButtonFormField<T>(
    key: key,
    initialValue: value,
    isExpanded: true,
    decoration: field(label),
    items: [for (final v in values) DropdownMenuItem(value: v, child: Text(text(v), overflow: TextOverflow.ellipsis))],
    onChanged: onChanged,
  );
}
