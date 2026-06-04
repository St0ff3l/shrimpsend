import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/app_ui.dart';

/// 6 格验证码输入框，自动聚焦下一格、退格回退，数字键盘。
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.onCompleted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback? onCompleted;
  final bool enabled;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  static const int _length = 6;
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(_length, (_) => FocusNode());
    final parentText = widget.controller.text;
    _controllers = List.generate(
      _length,
      (i) => TextEditingController(
        text: i < parentText.length ? parentText[i] : '',
      ),
    );
    widget.controller.addListener(_syncFromParent);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncFromParent() {
    final s = widget.controller.text;
    for (var i = 0; i < _length; i++) {
      final char = i < s.length ? s[i] : '';
      if (_controllers[i].text != char) {
        _controllers[i].text = char;
      }
    }
  }

  void _syncToParent() {
    final buf = StringBuffer();
    for (final c in _controllers) {
      buf.write(c.text);
    }
    final newText = buf.toString();
    if (widget.controller.text != newText) {
      widget.controller.text = newText;
    }
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      var i = index;
      for (final d in digits) {
        if (i < _length) {
          _controllers[i].text = d;
          i++;
        }
      }
      if (i < _length) {
        _focusNodes[i].requestFocus();
      } else {
        _focusNodes[_length - 1].requestFocus();
        _onCompleteCheck();
      }
      _syncToParent();
      return;
    }
    if (value.isNotEmpty) {
      _controllers[index].text = value[value.length - 1];
      if (index < _length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
      _syncToParent();
      if (index == _length - 1) _onCompleteCheck();
    }
  }

  void _onCompleteCheck() {
    final s = widget.controller.text;
    if (s.length == _length) widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppThemeColors>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_length, (i) {
        return SizedBox(
          width: 44,
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              maxLength: 1,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.medium,
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.medium,
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.medium,
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.4,
                  ),
                ),
                filled: true,
                fillColor: colors.surface,
              ),
              onChanged: (v) => _onChanged(i, v),
            ),
        );
      }),
    );
  }
}
