import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// خانة رقم + اسمه، بتتغير بالضغط أو السحب أو السكرول أو بالضغط مرتين لتعديل الرقم
class TimerUnit extends StatefulWidget {
  const TimerUnit({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    required this.onChange,
    this.onSetValue,
  });

  /// الرقم المعروض
  final int value;

  /// قيمة الخانة بالثواني: 3600 ساعة، 60 دقيقة، 1 ثانية
  final int unit;

  final String label;

  final void Function(int unit, int delta) onChange;
  final void Function(int unit, int newValue)? onSetValue;

  @override
  State<TimerUnit> createState() => _TimerUnitState();
}

class _TimerUnitState extends State<TimerUnit> {
  double drag = 0;
  bool _isEditing = false;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _finishEditing();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _textController.text = widget.value.toString().padLeft(2, '0');
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _finishEditing() {
    if (!_isEditing) return;
    final maxVal = widget.unit == 3600 ? 99 : 59;
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed != null) {
        final clamped = parsed.clamp(0, maxVal);
        if (widget.onSetValue != null) {
          widget.onSetValue!(widget.unit, clamped);
        } else {
          widget.onChange(widget.unit, clamped - widget.value);
        }
      }
    }
    if (mounted) {
      setState(() {
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 42,
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              cursorColor: Colors.green,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _finishEditing(),
              onTapOutside: (_) => _finishEditing(),
            ),
          ),
          Text(
            widget.label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => widget.onChange(widget.unit, 1),
      onDoubleTap: _startEditing,
      onLongPress: _startEditing,
      onVerticalDragStart: (_) => drag = 0,
      onVerticalDragUpdate: (details) {
        drag += details.delta.dy;
        final steps = drag ~/ 20;
        if (steps != 0) {
          drag -= steps * 20;
          widget.onChange(widget.unit, -steps);
        }
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            widget.onChange(widget.unit, event.scrollDelta.dy < 0 ? 1 : -1);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.value.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              widget.label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
