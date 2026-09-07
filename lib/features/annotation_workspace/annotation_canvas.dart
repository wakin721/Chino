import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/annotation/annotation.dart';
import '../../domain/annotation/bounding_box.dart';
import '../../domain/dataset/dataset_image.dart';

class AnnotationCanvas extends StatefulWidget {
  const AnnotationCanvas({super.key, required this.image, required this.annotations, required this.categoryNames, required this.selectedId, required this.onSelect, required this.onCreate, required this.onUpdate});
  final DatasetImage image;
  final List<Annotation> annotations;
  final Map<String, String> categoryNames;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<BoundingBox> onCreate;
  final void Function(String id, BoundingBox box) onUpdate;
  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

class _ViewTransform {
  const _ViewTransform(this.scale, this.offset);
  final double scale;
  final Offset offset;
  Offset toImage(Offset point) => (point - offset) / scale;
  Rect toView(BoundingBox box) => Rect.fromLTWH(offset.dx + box.left * scale, offset.dy + box.top * scale, box.width * scale, box.height * scale);
}

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  Offset? _start;
  Offset? _current;
  String? _editingId;
  BoundingBox? _originalBox;
  bool _resizing = false;

  _ViewTransform _transform(BoxConstraints constraints) {
    final scale = math.min(constraints.maxWidth / widget.image.width, constraints.maxHeight / widget.image.height);
    final displayWidth = widget.image.width * scale;
    final displayHeight = widget.image.height * scale;
    return _ViewTransform(scale, Offset((constraints.maxWidth - displayWidth) / 2, (constraints.maxHeight - displayHeight) / 2));
  }

  Annotation? _hit(Offset imagePoint) {
    for (final annotation in widget.annotations.reversed) {
      final box = annotation.box;
      if (imagePoint.dx >= box.left && imagePoint.dx <= box.right && imagePoint.dy >= box.top && imagePoint.dy <= box.bottom) return annotation;
    }
    return null;
  }

  BoundingBox? _draftBox() {
    final start = _start;
    final current = _current;
    if (start == null || current == null) return null;
    if (_editingId != null && _originalBox != null) {
      final original = _originalBox!;
      if (_resizing) {
        return BoundingBox(left: original.left, top: original.top, width: math.max(1.0, current.dx - original.left), height: math.max(1.0, current.dy - original.top)).clampToImage(imageWidth: widget.image.width, imageHeight: widget.image.height);
      }
      final delta = current - start;
      return BoundingBox(left: original.left + delta.dx, top: original.top + delta.dy, width: original.width, height: original.height).clampToImage(imageWidth: widget.image.width, imageHeight: widget.image.height);
    }
    final left = math.min(start.dx, current.dx);
    final top = math.min(start.dy, current.dy);
    final right = math.max(start.dx, current.dx);
    final bottom = math.max(start.dy, current.dy);
    return BoundingBox(left: left, top: top, width: right - left, height: bottom - top).clampToImage(imageWidth: widget.image.width, imageHeight: widget.image.height);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final transform = _transform(constraints);
        final imageRect = Rect.fromLTWH(transform.offset.dx, transform.offset.dy, widget.image.width * transform.scale, widget.image.height * transform.scale);
        final draft = _draftBox();
        return ClipRect(child: Stack(children: [
          Positioned.fromRect(
            rect: imageRect,
            child: Image.file(
              File(widget.image.path),
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.black12, child: Center(child: Icon(Icons.broken_image_outlined))),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _AnnotationPainter(annotations: widget.annotations, categoryNames: widget.categoryNames, selectedId: widget.selectedId, transform: transform, draft: draft, editingId: _editingId))),
          Positioned.fill(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              final point = transform.toImage(details.localPosition);
              if (point.dx < 0 || point.dy < 0 || point.dx > widget.image.width || point.dy > widget.image.height) return;
              final hit = _hit(point);
              setState(() {
                _start = point; _current = point; _editingId = hit?.id; _originalBox = hit?.box;
                if (hit != null) {
                  widget.onSelect(hit.id);
                  _resizing = (point - Offset(hit.box.right, hit.box.bottom)).distance <= 14 / transform.scale;
                } else {
                  widget.onSelect(null); _resizing = false;
                }
              });
            },
            onPanUpdate: (details) {
              if (_start != null) {
                setState(() => _current = transform.toImage(details.localPosition));
              }
            },
            onPanEnd: (_) {
              final draftBox = _draftBox(); final id = _editingId;
              if (draftBox != null) {
                if (id != null) {
                  widget.onUpdate(id, draftBox);
                } else if (draftBox.width * transform.scale >= 4 && draftBox.height * transform.scale >= 4) {
                  widget.onCreate(draftBox);
                }
              }
              setState(() { _start = null; _current = null; _editingId = null; _originalBox = null; _resizing = false; });
            },
            onTapUp: (details) => widget.onSelect(_hit(transform.toImage(details.localPosition))?.id),
          )),
        ]));
      });
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({required this.annotations, required this.categoryNames, required this.selectedId, required this.transform, required this.draft, required this.editingId});
  final List<Annotation> annotations;
  final Map<String, String> categoryNames;
  final String? selectedId;
  final _ViewTransform transform;
  final BoundingBox? draft;
  final String? editingId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      final box = annotation.id == editingId && draft != null ? draft! : annotation.box;
      final rect = transform.toView(box);
      final selected = annotation.id == selectedId;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = selected ? 3 : 2..color = selected ? Colors.amber : Colors.lightBlueAccent;
      canvas.drawRect(rect, paint);
      if (selected) canvas.drawCircle(rect.bottomRight, 5, Paint()..color = Colors.amber);
      final label = categoryNames[annotation.categoryId] ?? annotation.categoryId;
      final text = annotation.confidence == null ? label : '$label ${(annotation.confidence! * 100).toStringAsFixed(0)}%';
      final painter = TextPainter(text: TextSpan(text: text, style: const TextStyle(fontSize: 12, color: Colors.white, backgroundColor: Colors.black87)), textDirection: TextDirection.ltr)..layout();
      painter.paint(canvas, Offset(rect.left, math.max(0.0, rect.top - painter.height)));
    }
    if (editingId == null && draft != null) canvas.drawRect(transform.toView(draft!), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.greenAccent);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
