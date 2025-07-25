import 'dart:math' show max;

import 'package:enmeshed_ui_kit/enmeshed_ui_kit.dart';
import 'package:flutter/material.dart';

import '../../utils/extensions.dart';
import '../../widgets/widgets.dart';

class EnterPassword extends StatefulWidget {
  final void Function(String password) onPasswordEntered;

  const EnterPassword({required this.onPasswordEntered, super.key});

  @override
  State<EnterPassword> createState() => _EnterPasswordState();
}

class _EnterPasswordState extends State<EnterPassword> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _passwordFocus.requestFocus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    _confirmPasswordController.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(title: context.l10n.identityRecovery_passwordTitle),
            Flexible(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.identityRecovery_passwordDescription),
                            Gaps.h24,
                            InformationCard(
                              title: context.l10n.identityRecovery_passwordAttention,
                              icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary, size: 40),
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            ),
                            Gaps.h36,
                            _PasswordTextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              label: context.l10n.identityRecovery_password,
                              validator: (value) {
                                if (value == null || value.isEmpty) return context.l10n.identityRecovery_passwordEmptyError;
                                return null;
                              },
                            ),
                            Gaps.h24,
                            _PasswordTextField(
                              controller: _confirmPasswordController,
                              focusNode: null,
                              label: context.l10n.identityRecovery_passwordConfirm,
                              validator: (value) {
                                if (value == null || value.isEmpty) return context.l10n.identityRecovery_passwordEmptyError;
                                if (value != _passwordController.text) return context.l10n.identityRecovery_passwordMismatch;
                                return null;
                              },
                            ),
                            Gaps.h24,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 8,
                bottom: max(MediaQuery.viewPaddingOf(context).bottom, MediaQuery.viewInsetsOf(context).bottom) + 8,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _onSubmit, child: Text(context.l10n.identityRecovery_startNow)),
              ),
            ),
          ],
        ),
        if (_loading) ModalLoadingOverlay(text: context.l10n.identityRecovery_generatingInProgress),
      ],
    );
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    widget.onPasswordEntered(_passwordController.text);
  }
}

class _PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? Function(String?) validator;

  const _PasswordTextField({required this.controller, required this.focusNode, required this.label, required this.validator});

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      validator: widget.validator,
    );
  }
}
