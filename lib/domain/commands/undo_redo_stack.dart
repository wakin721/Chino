import '../project/chino_project.dart';

typedef ProjectEdit = ChinoProject Function(ChinoProject project);

class UndoRedoStack {
  final List<ChinoProject> _undo = [];
  final List<ChinoProject> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  ChinoProject execute(ChinoProject current, ProjectEdit edit) {
    _undo.add(current);
    _redo.clear();
    return edit(current);
  }

  ChinoProject undo(ChinoProject current) {
    if (_undo.isEmpty) return current;
    _redo.add(current);
    return _undo.removeLast();
  }

  ChinoProject redo(ChinoProject current) {
    if (_redo.isEmpty) return current;
    _undo.add(current);
    return _redo.removeLast();
  }
}
