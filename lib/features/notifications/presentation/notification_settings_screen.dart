import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/notifications/cubit/notification_cubits.dart';
import 'package:lamsa_app/features/notifications/data/notifications_api.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:lamsa_app/features/notifications/presentation/push_widgets.dart';

/// The three switches the backend has (marketing, favorites, cart reminders),
/// and a note for what is always on: order updates (and the store's direct
/// messages). Quiet hours are applied by the backend.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) =>
            PreferencesCubit(context.read<NotificationsApi>())..load(),
        child: const _SettingsView(),
      );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  Future<void> _toggle(BuildContext context, PrefKey key, bool value) async {
    final error = await context.read<PreferencesCubit>().set(key, value: value);
    if (error != null) showToast(error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.prefsTitle)),
      body: BlocBuilder<PreferencesCubit, PrefsState>(
        builder: (context, state) {
          switch (state.status) {
            case PrefsLoad.loading:
              return const LoadingView(message: Strings.loading);
            case PrefsLoad.failed:
              return ErrorView(
                message: state.error ?? Strings.notifUnavailable,
                onRetry: () => context.read<PreferencesCubit>().load(),
              );
            case PrefsLoad.ready:
              break;
          }
          final c = context.lamsa;
          final p = state.prefs;
          return ListView(
            padding: const EdgeInsets.all(Spacing.pageGutter),
            children: [
              PushPermissionBanner(push: context.read<PushService>()),
              Text(
                Strings.prefsLead,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.muted),
              ),
              const SizedBox(height: Spacing.md),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Not a switch: order updates cannot be turned off.
                    ListTile(
                      leading: Icon(Icons.local_shipping_outlined, color: c.accent),
                      title: const Text(Strings.prefsOrderUpdates),
                      subtitle: const Text(Strings.prefsOrderUpdatesHint),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(
                          Strings.prefsAlwaysOn,
                          style: Theme.of(context).textTheme.labelSmall!.copyWith(color: c.ok),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _Switch(
                      title: Strings.prefsMarketing,
                      hint: Strings.prefsMarketingHint,
                      value: p.marketing,
                      onChanged: (v) => _toggle(context, PrefKey.marketing, v),
                    ),
                    const Divider(height: 1),
                    _Switch(
                      title: Strings.prefsFavorites,
                      hint: Strings.prefsFavoritesHint,
                      value: p.favorites,
                      onChanged: (v) => _toggle(context, PrefKey.favorites, v),
                    ),
                    const Divider(height: 1),
                    _Switch(
                      title: Strings.prefsCartReminders,
                      hint: Strings.prefsCartRemindersHint,
                      value: p.cartReminders,
                      onChanged: (v) => _toggle(context, PrefKey.cartReminders, v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                Strings.prefsStoreMessages,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: c.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(title),
        subtitle: Text(hint),
        value: value,
        onChanged: onChanged,
      );
}
