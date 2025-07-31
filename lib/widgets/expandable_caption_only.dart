import 'package:flutter/material.dart';

class ExpandableCaptionOnly extends StatefulWidget {
  final String caption;
  final int maxLines;
  final TextStyle? captionStyle;
  final TextStyle? moreStyle;

  const ExpandableCaptionOnly({
    Key? key,
    required this.caption,
    this.maxLines = 2,
    this.captionStyle,
    this.moreStyle,
  }) : super(key: key);

  @override
  State<ExpandableCaptionOnly> createState() => _ExpandableCaptionOnlyState();
}

class _ExpandableCaptionOnlyState extends State<ExpandableCaptionOnly> {
  bool _isExpanded = false;
  bool _shouldShowMoreButton = false;
  late TextPainter _textPainter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTextOverflow();
    });
  }

  @override
  void didUpdateWidget(ExpandableCaptionOnly oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caption != widget.caption) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkTextOverflow();
      });
    }
  }

  void _checkTextOverflow() {
    if (widget.caption.isEmpty) {
      setState(() {
        _shouldShowMoreButton = false;
      });
      return;
    }

    _textPainter = TextPainter(
      text: TextSpan(
        text: widget.caption,
        style: widget.captionStyle ?? const TextStyle(color: Colors.white),
      ),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    );

    // Account for padding and right controls space
    final double maxWidth = MediaQuery.of(context).size.width - 116; // Adjusted for layout

    _textPainter.layout(maxWidth: maxWidth);

    setState(() {
      _shouldShowMoreButton = _textPainter.didExceedMaxLines;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caption.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (_shouldShowMoreButton) {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            }
          },
          child: Text(
            widget.caption,
            style: widget.captionStyle ?? const TextStyle(color: Colors.white, fontSize: 15),
            maxLines: _isExpanded ? null : widget.maxLines,
            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
        if (_shouldShowMoreButton)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _isExpanded ? 'less' : 'more',
                style: widget.moreStyle ?? const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _textPainter.dispose();
    super.dispose();
  }
}