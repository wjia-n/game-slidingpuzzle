import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/atelier.dart';

/// Pro Workshop: Free-vs-Pro comparison, Pro unlock, tip jar.
/// Graceful when the store/products are not configured yet.
class ProScreen extends StatefulWidget {
  final WorkshopAudio audio;
  final WorkshopSettings settings;
  final StoreService? store; // null when opened without an init'ed store
  const ProScreen(
      {super.key, required this.audio, required this.settings, this.store});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  late final StoreService _store;
  bool _ownsStore = false;

  @override
  void initState() {
    super.initState();
    if (widget.store != null) {
      _store = widget.store!;
    } else {
      _store = StoreService();
      _ownsStore = true;
      _store.init().then((_) {
        if (mounted) setState(() {});
      });
    }
    _store.proPurchased.addListener(_onPro);
    _store.lastThanks.addListener(_onThanks);
  }

  
  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      _store.lastThanks.value = null;
    }
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onPro);
    _store.lastThanks.removeListener(_onThanks);
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    final s = widget.settings;
    return Scaffold(
      backgroundColor: t.backdrop,
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BrassRoundButton(
                      theme: t,
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      size: 44,
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 14),
                    Text('PRO WORKSHOP', style: AtelierType.display(20, t)),
                  ],
                ),
                const SizedBox(height: 18),
                BrassPlaque(
                    theme: t,
                    text: s.isPro
                        ? 'PRO UNLOCKED — ENJOY THE ATELIER'
                        : 'FREE vs PRO',
                    fontSize: 15),
                const SizedBox(height: 14),
                _compare(t, '6 workshop themes', 'All 12 themes + custom creator', s.isPro),
                _compare(t, '4 tile face styles', 'All 8 tile face styles', s.isPro),
                _compare(t, '2 frame styles', 'All 4 frame styles', s.isPro),
                _compare(t, '3×3 – 5×5 canvases', '6×6 Grand Master canvas', s.isPro),
                _compare(t, 'Classic + Beat the Clock', 'All 5 modes incl. Daily & Party', s.isPro),
                _compare(t, '1 hint per game', '1 hint per game', s.isPro),
                const SizedBox(height: 18),
                if (!s.isPro) ...[
                  if (!_store.storeReady)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: t.parchment,
                        border: Border.all(color: t.brassDark),
                      ),
                      child: Text(
                        'Purchases will be available after the store setup is complete. Everything else in the game is fully playable.',
                        textAlign: TextAlign.center,
                        style: AtelierType.body(13, t, color: t.inkBrown),
                      ),
                    )
                  else
                    OakButton(
                      theme: t,
                      label: _store.proProduct == null
                          ? 'PRO WORKSHOP'
                          : 'UNLOCK PRO — ${_store.proProduct!.price}',
                      sublabel: 'One-time purchase, yours forever',
                      onTap: () => _store.buyPro(),
                    ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: _store.purchaseError,
                    builder: (_, err, _) => err == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(err,
                                textAlign: TextAlign.center,
                                style: AtelierType.body(12, t,
                                    color: const Color(0xFFB0402A))),
                          ),
                  ),
                  TextButton(
                    onPressed: () => _store.restore(),
                    child: Text('Restore purchases',
                        style: AtelierType.label(12, t)),
                  ),
                ],
                const SizedBox(height: 18),
                Text('TIP JAR', style: AtelierType.label(13, t)),
                const SizedBox(height: 4),
                Text(
                  'Sliding Puzzle is made by one indie maker. Tips keep the workshop lights on — never required.',
                  style: AtelierType.body(12, t,
                      color: t.parchment.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _tipButton(
                            t, _store.coffeeProduct, '☕', 'Coffee')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _tipButton(t, _store.chocolateProduct, '🍫',
                            'Chocolate')),
                  ],
                ),
                if (!_store.storeReady)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _store.error ?? 'Tip jar opens after store setup.',
                      textAlign: TextAlign.center,
                      style: AtelierType.body(12, t,
                          color: t.parchment.withValues(alpha: 0.6)),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compare(AtelierTheme t, String free, String pro, bool isPro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: t.recess.withValues(alpha: 0.85),
        border: Border.all(color: t.brassDark, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(free,
                  style: AtelierType.body(12, t,
                      color: t.parchment.withValues(alpha: 0.65)))),
          Icon(Icons.arrow_forward, size: 14, color: t.brass),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pro,
                style: AtelierType.label(12, t,
                    color: isPro ? t.brassLight : t.parchment)),
          ),
        ],
      ),
    );
  }

  Widget _tipButton(
      AtelierTheme t, ProductDetails? product, String emoji, String label) {
    final ProductDetails? item =
        (_store.storeReady && product != null) ? product : null;
    final ready = item != null;
    return Opacity(
      opacity: ready ? 1.0 : 0.55,
      child: GestureDetector(
        onTap: ready
            ? () {
                widget.audio.click();
                _store.buyTip(item);
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.woodLight, t.woodMid, t.woodDark],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: t.brass, width: 2),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(label, style: AtelierType.label(12, t)),
              Text(ready ? item.price : '—',
                  style: AtelierType.body(11, t,
                      color: t.parchment.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}
