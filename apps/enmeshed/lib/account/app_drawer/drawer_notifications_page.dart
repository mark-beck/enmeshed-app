import 'package:enmeshed_ui_kit/enmeshed_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_graphics/vector_graphics.dart';

import '/core/utils/extensions.dart';

class DrawerNotificationsPage extends StatefulWidget {
  final VoidCallback goBack;

  const DrawerNotificationsPage({required this.goBack, super.key});

  @override
  State<DrawerNotificationsPage> createState() => DrawerNotificationsPageState();
}

class DrawerNotificationsPageState extends State<DrawerNotificationsPage> with WidgetsBindingObserver {
  PermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _recheckPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    _recheckPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.goBack),
        Text(
          context.l10n.drawer_notifications,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        const Spacer(),
        IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
      ],
    );

    if (_permissionStatus == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        Expanded(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 16),
                child: VectorGraphic(loader: AssetBytesLoader('assets/svg/notifications.svg'), height: 160),
              ),
              Gaps.h36,
              Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.drawer_notifications_stayInformed)),
              if (_permissionStatus == PermissionStatus.granted)
                Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.drawer_notifications_grantedInformation))
              else
                _ActivateNotifications(
                  permissionStatus: _permissionStatus!,
                  onRequestPermission: () async {
                    if (_permissionStatus == PermissionStatus.permanentlyDenied) {
                      await openAppSettings();
                    } else {
                      await Permission.notification.request();
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _recheckPermission() async {
    final permissionStatus = await Permission.notification.status;

    if (mounted) setState(() => _permissionStatus = permissionStatus);
  }
}

class _ActivateNotifications extends StatelessWidget {
  final VoidCallback onRequestPermission;
  final PermissionStatus permissionStatus;

  const _ActivateNotifications({required this.onRequestPermission, required this.permissionStatus});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.drawer_notifications_getNotifications),
          if (permissionStatus.isPermanentlyDenied) ...[Gaps.h24, Text(context.l10n.drawer_notifications_howToActivate)],
          Gaps.h48,
          FilledButton(onPressed: onRequestPermission, child: Text(context.l10n.drawer_notifications_activateButton)),
        ],
      ),
    );
  }
}
