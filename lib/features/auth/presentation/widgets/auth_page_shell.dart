import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/widgets/tasker_glass_surface.dart';
import 'sequential_fade_switcher.dart';

/// Layout de auth — header azul com logo + painel gelo (mesmo efeito do dock).
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.contentKey,
    this.footerKey,
    this.leading,
    this.footer,
    this.scrollController,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Object? contentKey;
  final Object? footerKey;
  final Widget? leading;
  final Widget? footer;
  final ScrollController? scrollController;

  static const _panelTopRadius = 40.0;
  static const _logoAsset = 'assets/icons/app_icon_face_512.png';
  static const _logoSize = 184.0;
  static const _contentFadeDuration = Duration(milliseconds: 130);
  /// Espaço reservado para o rodapé fixo (não sobe com o teclado).
  static const _footerReserve = 108.0;

  void _resetScrollPosition() {
    final controller = scrollController;
    if (controller != null && controller.hasClients) {
      controller.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panelHeight = size.height * 0.68;
    final blueAreaHeight = size.height - panelHeight;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final footerReserve = footer != null ? _footerReserve + bottomSafe : 0.0;
    final keyboardOpen = keyboardInset > 0;
    final scrollBottomPadding = keyboardOpen
        ? keyboardInset + 24
        : footerReserve + 24;
    final contentAnimationKey = contentKey ?? title;
    final topPadding = keyboardOpen ? 16.0 : (leading == null ? 32.0 : 16.0);

    return Scaffold(
      backgroundColor: TaskerColors.primary,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: blueAreaHeight,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Image.asset(
                  _logoAsset,
                  width: _logoSize,
                  height: _logoSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: panelHeight,
              width: double.infinity,
              child: TaskerGlassSurface(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(_panelTopRadius),
                  topRight: Radius.circular(_panelTopRadius),
                ),
                blurSigma: 24,
                tint: Colors.white,
                tintOpacity: 0.92,
                borderColor: Colors.white,
                borderOpacity: 0.95,
                borderWidth: 1.25,
                shadows: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 28,
                    offset: Offset(0, -4),
                  ),
                ],
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          28,
                          topPadding,
                          28,
                          scrollBottomPadding,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (leading != null) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: leading!,
                              ),
                              const SizedBox(height: 8),
                            ],
                            SequentialFadeSwitcher(
                              switchKey: contentAnimationKey,
                              duration: _contentFadeDuration,
                              onSwap: _resetScrollPosition,
                              child: Column(
                                key: ValueKey(contentAnimationKey),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!keyboardOpen) ...[
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: TaskerColors.primaryText,
                                        letterSpacing: -0.4,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: TaskerColors.secondaryText
                                            .withValues(alpha: 0.9),
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                  ] else ...[
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: TaskerColors.primaryText,
                                        letterSpacing: -0.3,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  child,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (footer != null)
                        Positioned(
                          left: 28,
                          right: 28,
                          bottom: 12 + bottomSafe,
                          child: SequentialFadeSwitcher(
                            switchKey: footerKey ?? contentAnimationKey,
                            duration: _contentFadeDuration,
                            child: footer!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
