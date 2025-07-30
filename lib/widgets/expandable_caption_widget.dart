import 'package:flutter/material.dart';

class ExpandableCaptionWidget extends StatefulWidget {
  final String username;
  final String? caption;
  final int maxLines;
  final TextStyle? usernameStyle;
  final TextStyle? captionStyle;
  final TextStyle? moreStyle;

  const ExpandableCaptionWidget({
    Key? key,
    required this.username,
    this.caption,
    this.maxLines = 2,
    this.usernameStyle,
    this.captionStyle,
    this.moreStyle,
  }) : super(key: key);

  @override
  State<ExpandableCaptionWidget> createState() => _ExpandableCaptionWidgetState();
}

class _ExpandableCaptionWidgetState extends State<ExpandableCaptionWidget> {
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
  void didUpdateWidget(ExpandableCaptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caption != widget.caption) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkTextOverflow();
      });
    }
  }

  void _checkTextOverflow() {
    if (widget.caption == null || widget.caption!.isEmpty) {
      setState(() {
        _shouldShowMoreButton = false;
      });
      return;
    }

    final fullText = '${widget.username} ${widget.caption!}';

    _textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${widget.username} ',
            style: widget.usernameStyle ?? const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: widget.caption!,
            style: widget.captionStyle ?? const TextStyle(color: Colors.white),
          ),
        ],
      ),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    );

    // Get the available width (you might need to adjust this based on your layout)
    final double maxWidth = MediaQuery.of(context).size.width - 28; // Account for padding

    _textPainter.layout(maxWidth: maxWidth);

    setState(() {
      _shouldShowMoreButton = _textPainter.didExceedMaxLines;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caption == null || widget.caption!.isEmpty) {
      return RichText(
        text: TextSpan(
          text: widget.username,
          style: widget.usernameStyle ?? const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _isExpanded ? () {
            setState(() {
              _isExpanded = false;
            });
          } : null,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${widget.username} ',
                  style: widget.usernameStyle ?? const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: widget.caption!,
                  style: widget.captionStyle ?? const TextStyle(color: Colors.white),
                ),
              ],
            ),
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