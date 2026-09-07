import 'dart:convert';
import 'dart:io';
import '../../domain/project/chino_project.dart';
import '../../domain/project/project_manifest_codec.dart';

class ProjectStore {
  Future<void> save(ChinoProject project, String path) async {
    final target = File(path);
    final temp = File('$path.tmp');
    final backup = File('$path.bak');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(jsonEncode(encodeProject(project)), flush: true);

    var movedOld = false;
    try {
      if (await backup.exists()) await backup.delete();
      if (await target.exists()) {
        await target.rename(backup.path);
        movedOld = true;
      }
      await temp.rename(target.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      if (movedOld && !await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  Future<ChinoProject> load(String path) async {
    final raw = jsonDecode(await File(path).readAsString());
    if (raw is! Map) throw const FormatException('Chino project root must be a JSON object.');
    return decodeProject(Map<String, Object?>.from(raw));
  }
}
