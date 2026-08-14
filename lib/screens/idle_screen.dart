import 'package:everafter/data/trip_repository.dart';
import 'package:everafter/widgets/museum_widgets.dart';
import 'package:everafter/widgets/trip_gallery.dart';
import 'package:everafter/screens/trip_experience_screen.dart';
import 'package:everafter/services/nfc_configuration.dart';
import 'package:everafter/services/nfc_service_provider.dart';
import 'package:everafter/state/museum_controller.dart';
import 'package:everafter/theme/everafter_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class IdleScreen extends ConsumerStatefulWidget {
  const IdleScreen({super.key});

  @override
  ConsumerState<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends ConsumerState<IdleScreen> {
  late final ScrollController _galleryController = ScrollController();
  bool _tripOpen = false;

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  void _moveGallery(double direction) {
    if (!_galleryController.hasClients) {
      return;
    }
    final position = _galleryController.position;
    final target = (_galleryController.offset + direction * 300).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _galleryController.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openTrip(TripGalleryItem trip, String heroTag) async {
    if (_tripOpen) return;

    setState(() => _tripOpen = true);
    await context.push<void>(
      '/trip/${trip.slug}',
      extra: TripExperienceRouteData(trip: trip, heroTag: heroTag),
    );
    if (!mounted) return;
    setState(() => _tripOpen = false);
  }

  Future<void> _confirmClose() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: EverAfterColors.paper,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: EverAfterColors.ink.withValues(alpha: 0.22)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: 440,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'MUSEUM SERVICES',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Close EverAfter?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  'The museum will close on this display. '
                  'You can reopen it from the Raspberry Pi launcher.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      key: const ValueKey('keep-everafter-open'),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('KEEP EXPLORING'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      key: const ValueKey('confirm-close-everafter'),
                      style: FilledButton.styleFrom(
                        backgroundColor: EverAfterColors.burgundy,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.power_settings_new, size: 18),
                      label: const Text('CLOSE APP'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (shouldClose == true) {
      ref.read(nfcServiceProvider).dispose();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await SystemNavigator.pop();
    }
  }

  Future<void> _scanMagnet() async {
    final message = await ref
        .read(museumControllerProvider.notifier)
        .requestNfcScan();
    if (!mounted || message == null) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _showNfcShortcutSetup() async {
    final links = _nfcTripLinks();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: EverAfterColors.paper,
        child: SizedBox(
          width: 760,
          height: 650,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 26, 30, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'IPHONE NFC SHORTCUTS',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Connect each magnet to its trip',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'In Shortcuts, create an Automation using the NFC trigger. '
                  'Scan the magnet, choose Run Immediately, then add Open URLs '
                  'with the matching EverAfter link below.',
                ),
                const SizedBox(height: 18),
                Expanded(child: _nfcLinkList(dialogContext, links)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('DONE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAndroidNfcSetup() async {
    final links = _nfcTripLinks();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: EverAfterColors.paper,
        child: SizedBox(
          width: 760,
          height: 690,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 26, 30, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ANDROID NFC SETUP',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Scan magnets on Android',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Turn on NFC in Android Settings. In EverAfter, tap Scan '
                  'Magnet and hold the NFC area on the back of the phone near '
                  'one magnet. EverAfter reads its UID and opens the linked trip.',
                ),
                const SizedBox(height: 14),
                Text(
                  'OPTIONAL · SCAN TO OPEN',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'For a writable magnet tag, use an NFC tag-writing app to '
                  'save the matching link below as its first NDEF URI record. '
                  'Scanning that tag while the phone is unlocked can open the '
                  'trip directly. Copying a link does not change the tag.',
                ),
                const SizedBox(height: 14),
                Expanded(child: _nfcLinkList(dialogContext, links)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('DONE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<({String name, String url})> _nfcTripLinks() {
    final repository = ref.read(tripRepositoryProvider);
    final links = <({String name, String url})>[];
    for (final artifact in repository.artifacts) {
      TripGalleryItem? matchedTrip;
      for (final trip in tripGalleryItems) {
        if (trip.name == artifact.place) {
          matchedTrip = trip;
          break;
        }
      }
      if (matchedTrip != null) {
        links.add((
          name: matchedTrip.name,
          url: 'everafter:///nfc/${matchedTrip.slug}',
        ));
      }
    }
    return links;
  }

  Widget _nfcLinkList(
    BuildContext dialogContext,
    List<({String name, String url})> links,
  ) {
    return ListView.separated(
      itemCount: links.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final link = links[index];
        return ListTile(
          dense: true,
          title: Text(link.name),
          subtitle: Text(link.url),
          trailing: const Icon(Icons.copy, size: 18),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: link.url));
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('${link.name} link copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isScanning = ref.watch(
      museumControllerProvider.select((museum) => museum.isScanning),
    );

    return PaperScaffold(
      includeDust: true,
      backgroundAsset: 'assets/textures/warm_linen_canvas_visible.jpg',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 28, 44, 0),
            child: Row(
              children: <Widget>[
                Text('MUSEUM OF TRAVELS', style: textTheme.titleLarge),
                const SizedBox(width: 14),
                Text('12 TRIPS · DRAG TO EXPLORE', style: textTheme.labelSmall),
                const Spacer(),
                IconButton.outlined(
                  key: const ValueKey('gallery-previous'),
                  tooltip: 'Previous trips',
                  onPressed: () => _moveGallery(-1),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const ValueKey('gallery-next'),
                  tooltip: 'More trips',
                  onPressed: () => _moveGallery(1),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 14),
                if (isAndroid) ...<Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey('android-nfc-setup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EverAfterColors.burgundy,
                      side: BorderSide(
                        color: EverAfterColors.burgundy.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    onPressed: _showAndroidNfcSetup,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('SETUP'),
                  ),
                  const SizedBox(width: 10),
                ],
                if ((isIos && nativeIosNfcEnabled) || isAndroid)
                  FilledButton.icon(
                    key: const ValueKey('scan-magnet'),
                    style: FilledButton.styleFrom(
                      backgroundColor: EverAfterColors.burgundy,
                      foregroundColor: EverAfterColors.paper,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                    ),
                    onPressed: isScanning ? null : _scanMagnet,
                    icon: isScanning
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              color: EverAfterColors.paper,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.nfc, size: 19),
                    label: Text(isScanning ? 'SCANNING' : 'SCAN MAGNET'),
                  )
                else if (isIos)
                  OutlinedButton.icon(
                    key: const ValueKey('nfc-shortcuts-setup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EverAfterColors.burgundy,
                      side: BorderSide(
                        color: EverAfterColors.burgundy.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    onPressed: _showNfcShortcutSetup,
                    icon: const Icon(Icons.nfc, size: 18),
                    label: const Text('NFC SETUP'),
                  )
                else
                  OutlinedButton.icon(
                    key: const ValueKey('close-everafter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EverAfterColors.burgundy,
                      side: BorderSide(
                        color: EverAfterColors.burgundy.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    onPressed: _confirmClose,
                    icon: const Icon(Icons.power_settings_new, size: 17),
                    label: const Text('CLOSE'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TripGallery(
                controller: _galleryController,
                autoScrollEnabled: !_tripOpen,
                onTripTap: _openTrip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
