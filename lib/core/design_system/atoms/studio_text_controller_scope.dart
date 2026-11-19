import 'package:flutter/widgets.dart';

/// Lifecycle-safe wrapper that owns a [TextEditingController] for ephemeral
/// dialogs and disposes it only after the route's exit animation unmounts.
class StudioTextControllerScope extends StatefulWidget {
  final String initialText;
  final Widget Function(BuildContext context, TextEditingController controller)
      builder;

  const StudioTextControllerScope({
    super.key,
    this.initialText = '',
    required this.builder,
  });

  @override
  State<StudioTextControllerScope> createState() =>
      _StudioTextControllerScopeState();
}

class _StudioTextControllerScopeState extends State<StudioTextControllerScope> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
