import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service.dart';
import '../providers/barber_shop_providers.dart';
import '../providers/firebase_providers.dart';

String _serviceFileStem(String filename) {
  final i = filename.lastIndexOf('.');
  if (i <= 0) return filename;
  return filename.substring(0, i);
}

bool _isServiceImageFileName(String name) {
  final n = name.toLowerCase();
  return n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.png') ||
      n.endsWith('.webp');
}

Future<List<Reference>> _listServiceFolderImages(FirebaseStorage storage, String slug) async {
  try {
    final list = await storage.ref('services/$slug').listAll();
    return list.items.where((e) => _isServiceImageFileName(e.name)).toList();
  } catch (_) {
    return [];
  }
}

/// Imagem de serviço: para URLs do Firebase Storage usa primeiro o SDK
/// ([Reference.getData]) — mais fiável que [Image.network] em mobile/web; senão usa rede.
class ServiceStorageImage extends StatefulWidget {
  const ServiceStorageImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.showLoading = true,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final bool showLoading;

  @override
  State<ServiceStorageImage> createState() => _ServiceStorageImageState();
}

class _ServiceStorageImageState extends State<ServiceStorageImage> {
  Uint8List? _memory;
  int _loadGen = 0;
  /// URL HTTP após resolver `gs://` ( [Image.network] não aceita gs ).
  String? _httpUrl;
  /// Depois de falhar com SDK, tenta [Image.network] (URLs externas ou token antigo).
  bool _allowNetworkFallback = false;
  bool _errorRecoverScheduled = false;
  bool _gsResolveFailed = false;

  static bool _isFirebaseStorageHttpUrl(String url) {
    final u = url.toLowerCase();
    return u.startsWith('gs://') ||
        u.contains('firebasestorage.googleapis.com') ||
        u.contains('firebasestorage.app') ||
        u.contains('.storage.googleapis.com');
  }

  @override
  void initState() {
    super.initState();
    final u = widget.imageUrl.trim();
    if (u.isNotEmpty && !u.startsWith('gs://')) {
      _httpUrl = u;
      if (kIsWeb && u.startsWith('http')) {
        _allowNetworkFallback = true;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _kickoffLoad();
    });
  }

  @override
  void didUpdateWidget(ServiceStorageImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      _memory = null;
      _httpUrl = null;
      _allowNetworkFallback = false;
      _errorRecoverScheduled = false;
      _gsResolveFailed = false;
      _loadGen++;
      final u = widget.imageUrl.trim();
      if (u.isNotEmpty && !u.startsWith('gs://')) {
        _httpUrl = u;
        if (kIsWeb && u.startsWith('http')) {
          _allowNetworkFallback = true;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _kickoffLoad();
      });
    }
  }

  Future<void> _kickoffLoad() async {
    final gen = _loadGen;
    var url = widget.imageUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _allowNetworkFallback = true);
      return;
    }
    if (url.startsWith('gs://')) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        url = await ref.getDownloadURL();
        if (!mounted || gen != _loadGen) return;
        setState(() {
          _httpUrl = url;
          if (kIsWeb) _allowNetworkFallback = true;
        });
      } catch (_) {
        if (mounted) setState(() => _gsResolveFailed = true);
      }
      return;
    }

    // Web: não usar fetch/XHR (CORS) nem o modo "never" do [Image.network] — ver build().
    if (kIsWeb) return;

    if (mounted) {
      setState(() => _httpUrl = url);
    } else {
      _httpUrl = url;
    }

    if (_isFirebaseStorageHttpUrl(url)) {
      await _loadFromFirebaseSdkForUrl(url);
    } else {
      if (mounted) setState(() => _allowNetworkFallback = true);
    }
  }

  Future<void> _loadFromFirebaseSdkForUrl(String url) async {
    final gen = _loadGen;
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final bytes = await ref.getData(5 * 1024 * 1024);
      if (!mounted || gen != _loadGen) return;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() => _memory = bytes);
        return;
      }
    } catch (_) {
      // URL inválida, token ou objeto apagado — tenta rede abaixo.
    }
    if (!mounted || gen != _loadGen) return;
    setState(() => _allowNetworkFallback = true);
  }

  Future<void> _tryStorageDownloadFromNetworkUrl() async {
    final gen = _loadGen;
    final src = _httpUrl ?? widget.imageUrl;
    try {
      final ref = FirebaseStorage.instance.refFromURL(src);
      final bytes = await ref.getData(5 * 1024 * 1024);
      if (!mounted || gen != _loadGen) return;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() => _memory = bytes);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_memory != null) {
      return Image.memory(
        _memory!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: Alignment.center,
      );
    }

    final defPlaceholder = ColoredBox(
      color: const Color(0xFFF3F4F6),
      child: SizedBox(width: widget.width, height: widget.height),
    );

    if (widget.imageUrl.trim().startsWith('gs://')) {
      if (_gsResolveFailed) {
        return widget.placeholder ?? defPlaceholder;
      }
      if (_httpUrl == null) {
        return widget.placeholder ??
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: widget.showLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : defPlaceholder,
            );
      }
    }

    final netUrl = _httpUrl ?? widget.imageUrl.trim();
    final webUseImgElement =
        kIsWeb && netUrl.startsWith('http') && !widget.imageUrl.trim().startsWith('gs://');

    if (_isFirebaseStorageHttpUrl(netUrl) && !_allowNetworkFallback && !webUseImgElement) {
      return widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: widget.showLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : defPlaceholder,
          );
    }

    return Image.network(
      netUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: Alignment.center,
      webHtmlElementStrategy:
          kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      loadingBuilder: widget.showLoading
          ? (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
          : null,
      errorBuilder: (context, error, stack) {
        if (!_errorRecoverScheduled && _isFirebaseStorageHttpUrl(netUrl)) {
          _errorRecoverScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_tryStorageDownloadFromNetworkUrl());
          });
        }
        return widget.placeholder ?? defPlaceholder;
      },
    );
  }
}

/// Lado da pré-visualização quadrada no formulário (lista e agendamento usam o mesmo recorte [BoxFit.cover]).
const double kServicePhotoEditorPreviewSide = 220;

/// Moldura quadrada única: onde a foto aparece no app (centrada, preenche o quadrado).
class ServiceImageSquareFrame extends StatelessWidget {
  const ServiceImageSquareFrame({
    super.key,
    required this.side,
    this.borderRadius = 16,
    this.borderColor = const Color(0xFFE5E7EB),
    required this.child,
  });

  final double side;
  final double borderRadius;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: SizedBox.expand(child: child),
    );
  }
}

Widget serviceImageEmptySquarePlaceholder({required double side}) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: side * 0.2, color: const Color(0xFF9CA3AF)),
        const SizedBox(height: 8),
        Text(
          'Toque em Escolher imagem',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: side > 180 ? 14 : 12, color: const Color(0xFF6B7280)),
        ),
      ],
    ),
  );
}

/// Miniatura **quadrada** para listas (dashboard, agendamento do cliente): [Service.imageUrl] ou Storage.
Widget serviceSquareListImage({
  required String shopDocId,
  required Service service,
  double side = 80,
  Widget? placeholder,
}) {
  final url = service.imageUrl?.trim();
  final hasUrl = url != null && url.isNotEmpty;
  final ph = placeholder ??
      ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: Icon(Icons.content_cut_rounded, color: Colors.grey.shade500, size: side * 0.38),
      );
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: side,
      height: side,
      child: hasUrl
          ? ServiceStorageImage(
              key: ValueKey('svc_sq_${service.id}_$url'),
              imageUrl: url,
              width: side,
              height: side,
              fit: BoxFit.cover,
              showLoading: true,
              placeholder: SizedBox(width: side, height: side, child: ph),
            )
          : ServiceThumbnailImage(
              slug: shopDocId,
              serviceId: service.id,
              imageUrl: null,
              width: side,
              height: side,
              borderRadius: 0,
              fit: BoxFit.cover,
              showLoading: true,
              placeholder: SizedBox(width: side, height: side, child: ph),
            ),
    ),
  );
}

/// Miniatura do serviço: 1) [imageUrl] no Firestore (ou dados equivalentes no modelo); senão
/// tenta Storage: `services/{slug}/{id}.ext`, ficheiro com stem = id, emparelhamento N:N,
/// um ficheiro único, etc. Grava [imageUrl] quando descobre uma URL nova no Storage.
class ServiceThumbnailImage extends ConsumerStatefulWidget {
  const ServiceThumbnailImage({
    super.key,
    required this.slug,
    required this.serviceId,
    this.imageUrl,
    this.width = 72,
    this.height = 72,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
    this.placeholder,
    this.showLoading = true,
  });

  final String slug;
  final String serviceId;
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final bool showLoading;

  @override
  ConsumerState<ServiceThumbnailImage> createState() => _ServiceThumbnailImageState();
}

class _ServiceThumbnailImageState extends ConsumerState<ServiceThumbnailImage> {
  String? _resolvedUrl;
  bool _loading = true;

  static final Set<String> _persistedUrlByService = {};

  Future<List<Service>?> _servicesWhenReady() async {
    final v = ref.read(servicesProvider(widget.slug)).valueOrNull;
    if (v != null && v.isNotEmpty) return v;
    try {
      return await ref.read(servicesProvider(widget.slug).future);
    } catch (_) {
      return ref.read(servicesProvider(widget.slug)).valueOrNull;
    }
  }

  Future<void> _maybePersistDiscoveredUrl(String url) async {
    final key = '${widget.slug}::${widget.serviceId}';
    if (_persistedUrlByService.contains(key)) return;
    final existing = widget.imageUrl?.trim();
    if (existing != null && existing.isNotEmpty && existing == url) return;
    try {
      final fs = ref.read(firestoreProvider);
      await fs
          .collection(barbershopsCollection)
          .doc(widget.slug)
          .collection('services')
          .doc(widget.serviceId)
          .set({'imageUrl': url}, SetOptions(merge: true));
      _persistedUrlByService.add(key);
      ref.invalidate(servicesProvider(widget.slug));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final direct = widget.imageUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      _resolvedUrl = direct;
      _loading = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolve();
    });
  }

  @override
  void didUpdateWidget(ServiceThumbnailImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl ||
        old.serviceId != widget.serviceId ||
        old.slug != widget.slug) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final direct = widget.imageUrl?.trim();
    final directNonEmpty = direct != null && direct.isNotEmpty;
    if (directNonEmpty) {
      if (mounted) {
        setState(() {
          _resolvedUrl = direct;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);

    final storage = ref.read(firebaseStorageProvider);
    String? chosen;

    try {
      for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
        try {
          chosen = await storage.ref('services/${widget.slug}/${widget.serviceId}.$ext').getDownloadURL();
          break;
        } catch (_) {}
      }

      // Ficheiro na pasta com nome igual ao id do documento
      List<Reference>? folderRefs;
      Future<List<Reference>> refsInFolder() async {
        folderRefs ??= await _listServiceFolderImages(storage, widget.slug);
        return folderRefs!;
      }

      if (chosen == null || chosen.isEmpty) {
        final refs = await refsInFolder();
        for (final r in refs) {
          if (_serviceFileStem(r.name) == widget.serviceId) {
            chosen = await r.getDownloadURL();
            break;
          }
        }
      }

      // Mesmo número de imagens e de serviços
      if (chosen == null || chosen.isEmpty) {
        final refs = await refsInFolder();
        final services = await _servicesWhenReady();
        if (services != null &&
            services.isNotEmpty &&
            refs.length == services.length &&
            refs.isNotEmpty &&
            refs.length <= 24) {
          final sortedSvcs = [...services]..sort((a, b) => a.id.compareTo(b.id));
          final sortedRefs = [...refs]..sort((a, b) => a.name.compareTo(b.name));
          final idx = sortedSvcs.indexWhere((s) => s.id == widget.serviceId);
          if (idx >= 0 && idx < sortedRefs.length) {
            chosen = await sortedRefs[idx].getDownloadURL();
          }
        }
      }

      // Um único serviço e um único ficheiro na pasta
      if (chosen == null || chosen.isEmpty) {
        final refs = await refsInFolder();
        final services = await _servicesWhenReady();
        if (services != null &&
            services.length == 1 &&
            refs.length == 1 &&
            services.single.id == widget.serviceId) {
          chosen = await refs.single.getDownloadURL();
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _resolvedUrl = chosen;
        _loading = false;
      });
    }

    if (chosen != null && chosen.isNotEmpty) {
      unawaited(_maybePersistDiscoveredUrl(chosen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ??
        ColoredBox(
          color: const Color(0xFFF3F4F6),
          child: Icon(Icons.content_cut_rounded, color: Colors.grey.shade500, size: widget.width * 0.4),
        );

    if (_loading && widget.showLoading) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_resolvedUrl == null || _resolvedUrl!.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(width: widget.width, height: widget.height, child: placeholder),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: ServiceStorageImage(
        imageUrl: _resolvedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        showLoading: widget.showLoading,
        placeholder: SizedBox(width: widget.width, height: widget.height, child: placeholder),
      ),
    );
  }
}
