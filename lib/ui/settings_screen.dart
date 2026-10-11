import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';
import 'files.dart';

const regimes = ['MICRO', 'TURNOVER', 'GENERAL'];
const activities = [
  'SERVICES', 'TRADE', 'HIGH_TECH', 'CONSULTING', 'ENGINEERING', 'MARKETING', 'DESIGN',
  'TRANSLATION', 'LEGAL', 'ACCOUNTING', 'AGENCY', 'CUSTOM',
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppScope.of(context).tr;
    return Loader<(Map<String, dynamic>, Map<String, dynamic>)>(
      load: (s) async => (
        await s.api.get('/api/profile') as Map<String, dynamic>,
        await s.api.get('/api/rules?year=${s.year}') as Map<String, dynamic>,
      ),
      builder: (context, data) => AppPage(
        title: tr('set.title'),
        subtitle: tr('set.lead'),
        children: [
          _ProfileForm(profile: data.$1, rules: data.$2),
          const _Reminders(),
          Grid(minWidth: 380, children: const [_Password(), _Export()]),
        ],
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.profile, required this.rules});

  final Map<String, dynamic> profile;
  final Map<String, dynamic> rules;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(text: widget.profile['name'] as String);
  late final _tin = TextEditingController(text: widget.profile['tin'] as String);
  late final _address = TextEditingController(text: widget.profile['address'] as String);
  late final _bank = TextEditingController(text: widget.profile['bankAccount'] as String);
  late final _rate = TextEditingController(text: '${widget.profile['customRate'] ?? ''}');
  late String _regime = widget.profile['regime'] as String;
  late String _activity = widget.profile['activity'] as String;

  Map<String, Map<String, dynamic>> get _byActivity => {
        for (final a in (widget.rules['activities'] as List).cast<Map<String, dynamic>>()) a['activity'] as String: a,
      };

  bool get _customRate => _regime == 'TURNOVER' && _activity == 'CUSTOM';

  @override
  void dispose() {
    for (final c in [_name, _tin, _address, _bank, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppScope.read(context);
    final ok = await guarded(context, () => s.api.put('/api/profile', {
          'name': _name.text,
          'tin': _tin.text,
          'address': _address.text,
          'bankAccount': _bank.text,
          'regime': _regime,
          'activity': _activity,
          'customRate': _customRate && _rate.text.isNotEmpty ? _rate.text : null,
        }));
    if (ok && mounted) {
      toast(context, s.tr('set.saved'));
      s.changed();
      s.go(AppTab.overview);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final allowed = ((_byActivity[_activity]?['allowedRegimes'] as List?) ?? const []).cast<String>();
    String activityLabel(String a) {
      final rate = _byActivity[a]?['turnoverRate'];
      return rate == null ? tr('activity.$a') : '${tr('activity.$a')} ($rate%)';
    }

    return Section(children: [
      Text(tr('set.person'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      FieldRow(minWidth: 260, children: [
        TextField(key: const Key('profile-name'), controller: _name, maxLength: 200, decoration: field(tr('set.name'))),
        TextField(controller: _tin, maxLength: 20, decoration: field(tr('set.tin'))),
        TextField(controller: _address, maxLength: 300, decoration: field(tr('set.address'))),
        TextField(controller: _bank, maxLength: 50, decoration: field(tr('set.bank'))),
      ]),
      Text(tr('set.regimeTitle'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      FieldRow(minWidth: 240, children: [
        dropdown<String>(
          key: const Key('regime'),
          label: tr('set.regime'),
          value: _regime,
          values: regimes,
          text: (r) => tr('regime.$r'),
          onChanged: (v) => setState(() => _regime = v!),
        ),
        dropdown<String>(
          key: const Key('activity'),
          label: tr('set.activity'),
          value: _activity,
          values: activities,
          text: activityLabel,
          onChanged: (v) => setState(() => _activity = v!),
        ),
        if (_customRate)
          TextField(
            controller: _rate,
            decoration: field(tr('set.customRate')),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
      ]),
      if (!allowed.contains(_regime))
        Notice(
          tr('set.notAllowed', {
            'activity': tr('activity.$_activity'),
            'regime': tr('regime.$_regime'),
            'allowed': allowed.map((r) => tr('regime.$r')).join(', '),
          }),
          bad: true,
          key: const Key('regime-check'),
        ),
      Text(
        tr('set.hint', {
          'micro': s.fmt.number((Fmt.toNum(widget.rules['microThreshold']) ?? 0) / 1e6),
          'turnover': s.fmt.number((Fmt.toNum(widget.rules['turnoverThreshold']) ?? 0) / 1e6),
          'year': widget.rules['rulesFromYear'],
        }),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(key: const Key('profile-save'), onPressed: _save, child: Text(tr('common.save'))),
      ),
    ]);
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final me = s.me!;
    final calendarUrl = s.api.url(me['calendarPath'] as String).toString();
    return Section(title: tr('set.reminders'), children: [
      Text(tr('set.calendar'), style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: SelectableText(calendarUrl, maxLines: 1)),
        IconButton(
          tooltip: tr('common.copy'),
          icon: const Icon(Icons.copy),
          onPressed: () => copyText(context, calendarUrl),
        ),
        IconButton(
          tooltip: tr('set.calendar'),
          icon: const Icon(Icons.event),
          // webcal:// открывает подписку в календаре телефона.
          onPressed: () => openLink(context, calendarUrl.replaceFirst(RegExp('^https?'), 'webcal')),
        ),
      ]),
      Text(tr('set.calendarHint'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      Text(tr('set.telegram'), style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (me['telegramEnabled'] != true)
        Text(tr('set.telegramOff'), style: Theme.of(context).textTheme.bodySmall)
      else if (me['telegramLinked'] == true)
        Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(tr('set.telegramLinked')),
          OutlinedButton(
            onPressed: () => guarded(context, () async {
              s.setMe(await s.api.delete('/api/account/telegram') as Map<String, dynamic>);
            }),
            child: Text(tr('set.telegramUnlink')),
          ),
        ])
      else
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.send),
            label: Text(tr('set.telegramConnect')),
            onPressed: () => guarded(context, () async {
              final r = await s.api.post('/api/account/telegram') as Map<String, dynamic>;
              if (context.mounted) {
                toast(context, tr('set.telegramOpen'));
                await openLink(context, r['link'] as String);
              }
            }),
          ),
        ),
    ]);
  }
}

class _Password extends StatefulWidget {
  const _Password();

  @override
  State<_Password> createState() => _PasswordState();
}

class _PasswordState extends State<_Password> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    return Section(title: tr('set.account'), children: [
      Text(s.me!['email'] as String),
      const SizedBox(height: 12),
      Form(
        key: _form,
        child: Column(children: [
          TextFormField(
            controller: _old,
            obscureText: true,
            decoration: field(tr('set.oldPassword')),
            validator: (v) => (v ?? '').isEmpty ? tr('set.oldPassword') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _new,
            obscureText: true,
            decoration: field(tr('set.newPassword'), helper: tr('auth.passwordHint')),
            validator: (v) => (v ?? '').length >= 8 ? null : tr('auth.passwordHint'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final ok = await guarded(context, () async => s.setMe(await s.api.changePassword(_old.text, _new.text)));
                if (ok && context.mounted) {
                  _old.clear();
                  _new.clear();
                  toast(context, tr('set.passwordChanged'));
                }
              },
              child: Text(tr('set.changePassword')),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Export extends StatelessWidget {
  const _Export();

  @override
  Widget build(BuildContext context) {
    final tr = AppScope.of(context).tr;
    return Section(title: tr('set.export'), children: [
      Text(tr('set.exportHint'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(
          onPressed: () => exportFile(context, '/api/export/data.json', 'pulsar-tax.json', 'application/json'),
          child: Text(tr('set.exportJson')),
        ),
        OutlinedButton(
          onPressed: () => exportFile(context, '/api/export/incomes.csv', 'incomes.csv', 'text/csv'),
          child: Text(tr('set.exportIncomes')),
        ),
        OutlinedButton(
          onPressed: () => exportFile(context, '/api/export/invoices.csv', 'invoices.csv', 'text/csv'),
          child: Text(tr('set.exportInvoices')),
        ),
        OutlinedButton(
          onPressed: () => exportFile(context, '/api/export/expenses.csv', 'expenses.csv', 'text/csv'),
          child: Text(tr('set.exportExpenses')),
        ),
      ]),
    ]);
  }
}
