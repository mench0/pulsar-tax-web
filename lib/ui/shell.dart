import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import 'common.dart';
import 'incomes_screen.dart';
import 'invoices_screen.dart';
import 'overview_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

/// Каркас после входа: вкладки снизу на телефоне и слева на широком экране.
class Shell extends StatelessWidget {
  const Shell({super.key});

  static const _icons = {
    AppTab.overview: Icons.dashboard_outlined,
    AppTab.incomes: Icons.payments_outlined,
    AppTab.report: Icons.receipt_long_outlined,
    AppTab.invoices: Icons.request_quote_outlined,
    AppTab.settings: Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = switch (s.tab) {
      AppTab.overview => const OverviewScreen(),
      AppTab.incomes => const IncomesScreen(),
      AppTab.report => const ReportScreen(),
      AppTab.invoices => const InvoicesScreen(),
      AppTab.settings => const SettingsScreen(),
    };
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle(),
        actions: [
          const YearMenu(),
          const LanguageMenu(),
          IconButton(
            key: const Key('logout'),
            tooltip: tr('nav.logout'),
            icon: const Icon(Icons.logout),
            onPressed: () => guarded(context, s.signOut),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: s.tab.index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => s.go(AppTab.values[i]),
                destinations: [
                  for (final t in AppTab.values)
                    NavigationRailDestination(icon: Icon(_icons[t]), label: Text(tr('nav.${t.name}'))),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: s.tab.index,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (i) => s.go(AppTab.values[i]),
              destinations: [
                for (final t in AppTab.values)
                  NavigationDestination(
                    key: Key('tab-${t.name}'),
                    icon: Icon(_icons[t]),
                    label: tr('nav.${t.name}'),
                  ),
              ],
            ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.radio_button_checked, color: Brand.red),
      const SizedBox(width: 8),
      Flexible(
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Pulsar '),
            TextSpan(text: 'Tax', style: TextStyle(color: Brand.red, fontWeight: FontWeight.w600)),
          ]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PopupMenuButton<String>(
      key: const Key('lang'),
      tooltip: Tr.languages[s.tr.lang],
      initialValue: s.tr.lang,
      onSelected: (l) => guarded(context, () => s.setLang(l)),
      itemBuilder: (_) => [for (final e in Tr.languages.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.translate, size: 20),
          const SizedBox(width: 4),
          Text(s.tr.lang.toUpperCase()),
        ]),
      ),
    );
  }
}

class YearMenu extends StatelessWidget {
  const YearMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = Fmt.currentYear();
    return PopupMenuButton<int>(
      key: const Key('year'),
      tooltip: s.tr('nav.year'),
      initialValue: s.year,
      onSelected: s.setYear,
      itemBuilder: (_) => [for (var y = now + 1; y >= now - 4; y--) PopupMenuItem(value: y, child: Text('$y'))],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${s.year}'),
          const Icon(Icons.arrow_drop_down),
        ]),
      ),
    );
  }
}
