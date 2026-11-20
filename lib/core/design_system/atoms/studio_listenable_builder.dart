import 'package:flutter/widgets.dart';
import '../../domain/i_studio_listenable.dart';

/// Builder reactivo para la capa de presentación que escucha contratos puros [IStudioListenable].
class StudioListenableBuilder extends StatefulWidget {
  final IStudioListenable listenable;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const StudioListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

  @override
  State<StudioListenableBuilder> createState() => _StudioListenableBuilderState();
}

class _StudioListenableBuilderState extends State<StudioListenableBuilder> {
  void _handleChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant StudioListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_handleChange);
      widget.listenable.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_handleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.child);
  }
}
