import 'package:enmeshed_types/enmeshed_types.dart';
import 'package:flutter/material.dart';
import 'package:value_renderer/value_renderer.dart';

import '../../../checkbox_settings.dart';

class ValueRendererListTile extends StatefulWidget {
  final String fieldName;
  final RenderHints renderHints;
  final ValueHints valueHints;
  final InputDecoration? decoration;
  final AttributeValue? initialValue;
  final ValueRendererController? controller;
  final void Function({String? valueType, ValueRendererInputValue? inputValue, required bool isComplex}) onUpdateInput;
  final String valueType;
  final CheckboxSettings? checkboxSettings;
  final bool mustBeAccepted;

  final Future<FileDVO> Function(String) expandFileReference;
  final Future<FileDVO?> Function() chooseFile;
  final void Function(FileDVO) openFileDetails;

  const ValueRendererListTile({
    super.key,
    required this.fieldName,
    required this.renderHints,
    required this.valueHints,
    this.decoration,
    this.initialValue,
    this.controller,
    required this.valueType,
    this.checkboxSettings,
    required this.onUpdateInput,
    required this.mustBeAccepted,
    required this.expandFileReference,
    required this.chooseFile,
    required this.openFileDetails,
  });

  @override
  State<ValueRendererListTile> createState() => _ValueRendererListTileState();
}

class _ValueRendererListTileState extends State<ValueRendererListTile> {
  final ValueRendererController controller = ValueRendererController();

  @override
  void initState() {
    super.initState();

    controller.addListener(() {
      final value = controller.value;

      if (value is ValueRendererValidationError) {
        widget.onUpdateInput(
          inputValue: null,
          valueType: widget.valueType,
          isComplex: widget.renderHints.editType == RenderHintsEditType.Complex ? true : false,
        );

        return;
      }

      widget.onUpdateInput(
        inputValue: controller.value,
        valueType: widget.valueType,
        isComplex: widget.renderHints.editType == RenderHintsEditType.Complex ? true : false,
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          if (widget.checkboxSettings != null)
            Checkbox(value: widget.checkboxSettings!.isChecked, onChanged: widget.checkboxSettings!.onUpdateCheckbox),
          Expanded(
            child: ValueRenderer(
              fieldName: widget.fieldName,
              renderHints: widget.renderHints,
              valueHints: widget.valueHints,
              initialValue: widget.initialValue,
              valueType: widget.valueType,
              controller: controller,
              mustBeFilledOut: widget.checkboxSettings?.isChecked ?? widget.mustBeAccepted,
              expandFileReference: widget.expandFileReference,
              chooseFile: widget.chooseFile,
              openFileDetails: widget.openFileDetails,
            ),
          ),
        ],
      ),
    );
  }
}
