// Detects backend API drift. Fetches the live OpenAPI schema and compares it
// with the committed snapshot (tool/openapi.snapshot.json).
//
//   dart run tool/check_openapi.dart            compare, exit 1 on drift
//   dart run tool/check_openapi.dart --update   rewrite the snapshot
//
// Backend URL: first argument that is not a flag, else API_BASE_URL, else
// http://127.0.0.1:8000. Run it against a backend started from the branch
// you are building against, then review the printed diff and update the
// hand-written models in lib/features/*/data when something changed.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final urlArg = args.where((a) => !a.startsWith('--')).firstOrNull;
  final origin = (urlArg ??
          Platform.environment['API_BASE_URL'] ??
          'http://127.0.0.1:8000')
      .replaceAll(RegExp(r'/+$'), '');

  final client = HttpClient();
  final Map<String, dynamic> live;
  try {
    final request = await client.getUrl(Uri.parse('$origin/openapi.json'));
    final response = await request.close();
    if (response.statusCode != 200) {
      stderr.writeln('GET $origin/openapi.json -> ${response.statusCode}');
      exit(2);
    }
    live = jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
  } on SocketException catch (e) {
    stderr.writeln('Cannot reach backend at $origin: ${e.message}');
    exit(2);
  } finally {
    client.close();
  }

  final snapshotFile = File('tool/openapi.snapshot.json');
  if (update || !snapshotFile.existsSync()) {
    snapshotFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(_sorted(live))}\n',
    );
    stdout.writeln('Snapshot written: ${snapshotFile.path}');
    return;
  }

  final saved =
      jsonDecode(snapshotFile.readAsStringSync()) as Map<String, dynamic>;
  final changes = <String>[];
  _diffPaths(saved, live, changes);
  _diffSchemas(saved, live, changes);
  if (changes.isEmpty) {
    stdout.writeln('No API drift.');
    return;
  }
  stdout.writeln('API drift detected (${changes.length}):');
  changes.forEach(stdout.writeln);
  stdout.writeln('Update models, then run with --update to accept.');
  exit(1);
}

Map<String, dynamic> _map(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

void _diffPaths(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  List<String> out,
) {
  final pa = _map(a['paths']);
  final pb = _map(b['paths']);
  for (final path in {...pa.keys, ...pb.keys}) {
    if (!pa.containsKey(path)) {
      out.add('+ path $path');
    } else if (!pb.containsKey(path)) {
      out.add('- path $path');
    } else if (jsonEncode(_sorted(pa[path])) != jsonEncode(_sorted(pb[path]))) {
      out.add('~ path $path');
    }
  }
}

void _diffSchemas(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  List<String> out,
) {
  final sa = _map(_map(a['components'])['schemas']);
  final sb = _map(_map(b['components'])['schemas']);
  for (final name in {...sa.keys, ...sb.keys}) {
    if (!sa.containsKey(name)) {
      out.add('+ schema $name');
    } else if (!sb.containsKey(name)) {
      out.add('- schema $name');
    } else if (jsonEncode(_sorted(sa[name])) != jsonEncode(_sorted(sb[name]))) {
      out.add('~ schema $name');
    }
  }
}

Object? _sorted(Object? v) {
  if (v is Map<String, dynamic>) {
    return {for (final k in v.keys.toList()..sort()) k: _sorted(v[k])};
  }
  if (v is List<Object?>) return v.map(_sorted).toList();
  return v;
}
