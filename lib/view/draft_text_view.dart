import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_draft/data/draft_data.dart';
import 'package:flutter_draft/type/block_type.dart';
import 'package:flutter_draft/util/text_util.dart';
import 'package:latext/latext.dart';

typedef OnLinkTab = void Function(String url);

class DraftTextView extends StatelessWidget {
  final String? indexNumber;
  final String? indexDelimiter;
  final TextStyle? indexStyle;
  final DraftData data;
  final TextStyle defaultStyle;
  final TextStyle? equationStyle;
  final OnLinkTab? onLinkTab;
  final double blockSpacing;
  final ScrollController? controller;
  final EdgeInsets? padding;

  DraftTextView.json(
    dynamic json, {
    Key? key,
    this.indexNumber,
    this.indexDelimiter = ". ",
    this.indexStyle,
    this.onLinkTab,
    this.defaultStyle = const TextStyle(fontSize: 12, color: Colors.black),
    this.equationStyle,
    this.controller,
    this.padding,
    this.blockSpacing = 8,
  })  : data = DraftData.fromJson(json),
        super(key: key);

  DraftTextView.jsonString(
    String json, {
    Key? key,
    this.indexNumber,
    this.indexDelimiter = ". ",
    this.indexStyle,
    this.onLinkTab,
    this.defaultStyle = const TextStyle(fontSize: 12, color: Colors.black),
    this.equationStyle,
    this.controller,
    this.padding,
    this.blockSpacing = 8,
  })  : data = DraftData.fromJson(jsonDecode(json)),
        super(key: key);

  const DraftTextView({
    Key? key,
    required this.data,
    this.indexNumber,
    this.indexDelimiter = ". ",
    this.indexStyle,
    this.onLinkTab,
    this.defaultStyle = const TextStyle(fontSize: 12, color: Colors.black),
    this.equationStyle,
    this.controller,
    this.padding,
    this.blockSpacing = 8,
  }) : super(key: key);

  int getDataLength() {
    return data.blocks.length;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      controller: controller,
      itemBuilder: _itemBuilder,
      itemCount: data.blocks.length,
      shrinkWrap: true,
      primary: false,
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    final block = data.blocks[index];
    return Builder(builder: (context) {
      try {
        return Padding(
          padding: EdgeInsets.only(bottom: blockSpacing),
          child: _blockBuilder(context, index, block),
        );
      } catch (ex) {
        return SizedBox();
      }
    });
  }

  Widget _blockBuilder(BuildContext context, int index, Block block) {
    Widget textView;
    TextStyle textStyle = _getTextStyle(
      Theme.of(context).textTheme,
      block,
    );

    // text view
    if (block.inlineStyle.isNotEmpty) {
      var styleMap = block.textStyleMap(textStyle);
      var inlineSpanList = styleMap
          .map((entry) => TextSpan(
                text: entry.key,
                style: entry.value,
              ))
          .toList();
      if (index == 0 && indexNumber != null) {
        inlineSpanList.insert(
            0,
            TextSpan(
              text: "$indexNumber$indexDelimiter",
              style: indexStyle ?? textStyle,
            ));
      }

      // IMPORTANT: Here are passing only the concatenated text to KaTex,
      // hence all the styles are ignore.
      // TODO: add functionlity in KaTex module to receive and render
      // list of text span.

      textView = LaTexT(
        laTeXCode: Text(
          TextSpan(
            children: inlineSpanList,
          ).toPlainText(),
          style: defaultStyle,
          textAlign: block.data.textAlign,
        ),
        equationStyle: equationStyle,
      );
    } else {
      textView = LaTexT(
        laTeXCode: Text(
          TextSpan(
            children: [
              if (index == 0 && indexNumber != null)
                TextSpan(
                  text: "$indexNumber$indexDelimiter",
                  style: indexStyle ?? textStyle,
                ),
              TextSpan(
                text: block.text,
                style: defaultStyle,
              ),
            ],
          ).toPlainText(),
          style: textStyle,
          textAlign: block.data.textAlign,
        ),
        equationStyle: equationStyle,
      );
    }

    // indented text
    if (!block.data.isEmpty && block.data.textIndent != 0) {
      return Padding(
        padding: EdgeInsets.only(
          left: TextUtil.measureText(' ', textStyle).width *
              block.data.textIndent,
        ),
        child: textView,
      );
    }

    // quote
    if (block.type == BlockType.quote) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(
            left: BorderSide(
              color: Colors.grey.shade300,
              width: 5,
            ),
          ),
        ),
        child: textView,
      );
    }

    // code
    if (block.type == BlockType.code) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade100,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: textView,
        ),
      );
    }

    // unordered list
    if (block.type == BlockType.bulletList) {
      var size = TextUtil.measureText(' ', textStyle);
      double dotSize = 5;
      const solid = BoxDecoration(color: Colors.black, shape: BoxShape.circle);
      var hollow = BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: Colors.black));
      Widget dot = Container(
        width: dotSize,
        height: dotSize,
        margin: EdgeInsets.only(
            right: dotSize,
            top: textStyle.fontSize! *
                0.2), // Adjust top margin for vertical alignment
        decoration: block.depth > 0 ? hollow : solid,
      );
      return Padding(
        padding: EdgeInsets.only(left: size.width * block.depth),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align items at the start vertically
          children: [
            dot,
            Expanded(
              // Use Expanded to allow text to wrap
              child: textView,
            ),
          ],
        ),
      );
    }

    // ordered list
    if (block.type == BlockType.numberList) {
      var size = TextUtil.measureText(' ', textStyle);
      Text numberView = Text('${block.data.number}.', style: textStyle);
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox.fromSize(
            size: Size(size.width * block.depth + size.width / 2, size.height),
            child: Align(alignment: Alignment.centerRight, child: numberView),
          ),
          textView,
        ],
      );
    }

    // entityRanges
    if (block.entityRanges.isNotEmpty) {
      List<Widget> children = [];
      String text = block.text;
      var entityMap = data.entityMap;
      for (var range in block.entityRanges) {
        var entity = entityMap["${range.key}"];
        if (entity == null) continue;
        switch (entity.type) {
          case EntityType.image:
            CachedNetworkImage image = CachedNetworkImage(
              imageUrl: entity.data.url ?? entity.data.src!,
              placeholder: (context, url) => const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              height: 120,
              fit: BoxFit.scaleDown,
              memCacheHeight: 300,
              memCacheWidth: 300,
            );
            children.add(image);
            if (entity.data.name?.isNotEmpty ?? false) {
              children.add(Text(entity.data.name!,
                  style: textStyle, textAlign: TextAlign.center));
            }
            break;
          case EntityType.divider:
            Divider divider = const Divider();
            children.add(divider);
            break;
          case EntityType.link:
            textView = Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text.substring(0, range.offset)),
                  TextSpan(
                    text: text.substring(
                        range.offset, range.offset + range.length),
                    style: textStyle.copyWith(
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => onLinkTab?.call(entity.data.url ?? ""),
                  ),
                  TextSpan(text: text.substring(range.offset + range.length)),
                ],
              ),
              textAlign: block.data.textAlign,
            );
            children.add(textView);
            break;
        }
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return textView;
  }

  TextStyle _getTextStyle(TextTheme textTheme, Block block) {
    TextStyle textStyle;
    switch (block.type) {
      case BlockType.h1:
        textStyle = textTheme.displayLarge ?? defaultStyle;
        break;
      case BlockType.h2:
        textStyle = textTheme.displayMedium ?? defaultStyle;
        break;
      case BlockType.h3:
        textStyle = textTheme.displaySmall ?? defaultStyle;
        break;
      case BlockType.h4:
        textStyle = textTheme.headlineMedium ?? defaultStyle;
        break;
      case BlockType.h5:
        textStyle = textTheme.headlineSmall ?? defaultStyle;
        break;
      case BlockType.h6:
        textStyle = textTheme.titleLarge ?? defaultStyle;
        break;
      case BlockType.code:
        textStyle = defaultStyle.copyWith(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        );
        break;
      case BlockType.quote:
        textStyle = TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
        );
        break;
      default:
        textStyle = textTheme.bodyMedium ?? defaultStyle;
        break;
    }
    return textStyle;
  }
}
