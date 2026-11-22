import 'package:aaroha_core/aaroha_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Training material bundled from the repo's `content/` folder (docs/06).
/// `app/content` is a symlink to it, since Flutter only bundles assets
/// inside the app's own folder.
class Content {
  const Content({required this.ragas, required this.alankars});

  /// In the order of the starter set (docs/06), easiest first.
  final List<Raga> ragas;
  final List<Alankar> alankars;

  Raga? raga(String id) => ragas.where((r) => r.id == id).firstOrNull;
  Alankar? alankar(String id) => alankars.where((a) => a.id == id).firstOrNull;
}

const ragaOrder = ['bhupali', 'yaman', 'bilawal', 'kafi', 'bhairav', 'durga', 'khamaj', 'des'];

Future<Content> loadContent(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final ragaFiles = manifest.listAssets().where(
    (a) => a.startsWith('content/ragas/') && a.endsWith('.yaml'),
  );
  final ragas = [for (final f in ragaFiles) Raga.fromYaml(await bundle.loadString(f))];
  int rank(Raga r) {
    final i = ragaOrder.indexOf(r.id);
    return i < 0 ? ragaOrder.length : i;
  }

  ragas.sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : a.name.compareTo(b.name));
  final alankars = Alankar.listFromYaml(await bundle.loadString('content/alankars/basic.yaml'));
  return Content(ragas: ragas, alankars: alankars);
}

final contentProvider = FutureProvider<Content>((ref) => loadContent(rootBundle));
