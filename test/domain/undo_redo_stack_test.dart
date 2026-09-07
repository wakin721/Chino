import 'package:chino/domain/commands/undo_redo_stack.dart';
import 'package:chino/domain/project/chino_project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('undo and redo restore immutable project snapshots', () {
    final stack = UndoRedoStack();
    const initial = ChinoProject(id: 'p', name: 'before', images: [], categories: [], annotations: []);
    final after = stack.execute(initial, (p) => p.copyWith(name: 'after'));
    expect(after.name, 'after');
    final undone = stack.undo(after); expect(undone.name, 'before');
    final redone = stack.redo(undone); expect(redone.name, 'after');
  });
}
