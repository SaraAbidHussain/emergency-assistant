import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isFocused = false;
  String? _errorText;

  // Quick-access recent IDs — swap this for real local storage later.
  final List<String> _recentIds = const ['ER-2041', 'ER-2039'];

  // ── Palette ─────────────────────────────────────────────
  static const Color background = Color(0xFF0A0D13);
  static const Color surface = Color(0xFF10151D);
  static const Color surfaceFocused = Color(0xFF131A23);
  static const Color primary = Color(0xFF5B8CFF);
  static const Color primaryViolet = Color(0xFF7B6EFF);
  static const Color success = Color(0xFF52D49A);
  static const Color danger = Color(0xFFE24B4A);
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF8993A3);
  static const Color textMuted = Color(0xFF5D6675);

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _idController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool _isValidFormat(String id) {
    // Loose validation so the demo isn't blocked by a strict pattern —
    // tighten this once the real ID scheme is finalized.
    return id.trim().length >= 4;
  }

  void _handleViewEmergency() {
    final id = _idController.text.trim();

    if (id.isEmpty) {
      setState(() => _errorText = 'Enter an emergency ID first');
      HapticFeedback.mediumImpact();
      return;
    }

    if (!_isValidFormat(id)) {
      setState(() => _errorText = 'That ID looks too short — check and try again');
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _errorText = null);
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(emergencyId: id),
      ),
    );
  }

  void _selectRecent(String id) {
    setState(() {
      _idController.text = id;
      _errorText = null;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = _idController.text.trim().isNotEmpty;
    final bool hasError = _errorText != null;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // Ambient gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.5),
                  radius: 1.2,
                  colors: [Color(0xFF111A2B), Color(0xFF0A0E15), background],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -140,
            left: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                height: 320,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [primary.withOpacity(0.10), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Network status pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: success.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: success.withOpacity(0.25), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: success),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Network live',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildBrandMark(),
                                const SizedBox(height: 28),
                                Text(
                                  'Responder access',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.6,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Real-time visibility into every\nactive emergency.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    height: 1.5,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 34),

                                // Label
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'EMERGENCY ID',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                      color: _isFocused
                                          ? primary
                                          : textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Input field
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: _isFocused
                                        ? [
                                            BoxShadow(
                                              color:
                                                  primary.withOpacity(0.14),
                                              blurRadius: 20,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: TextField(
                                    controller: _idController,
                                    focusNode: _focusNode,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleViewEmergency(),
                                    onChanged: (_) => setState(
                                        () => _errorText = null),
                                    style: GoogleFonts.inter(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w500,
                                      color: textPrimary,
                                    ),
                                    cursorColor: primary,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. ER-2048',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 15.5,
                                        color: textMuted,
                                      ),
                                      prefixIcon: Icon(Icons.tag_rounded,
                                          size: 19,
                                          color: _isFocused
                                              ? primary
                                              : textMuted),
                                      suffixIcon: hasText
                                          ? IconButton(
                                              icon: Icon(Icons.close_rounded,
                                                  size: 18,
                                                  color: textMuted),
                                              onPressed: () => setState(() {
                                                _idController.clear();
                                                _errorText = null;
                                              }),
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: _isFocused
                                          ? surfaceFocused
                                          : surface,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: hasError
                                              ? danger.withOpacity(0.6)
                                              : Colors.white
                                                  .withOpacity(0.06),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: hasError
                                              ? danger.withOpacity(0.6)
                                              : Colors.white
                                                  .withOpacity(0.06),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: hasError
                                              ? danger.withOpacity(0.7)
                                              : primary.withOpacity(0.7),
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Inline error — never block silently
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 180),
                                  child: hasError
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _errorText!,
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                color: danger,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),

                                const SizedBox(height: 16),

                                // Primary CTA — always enabled, validates on tap
                                GestureDetector(
                                  onTap: _handleViewEmergency,
                                  child: Container(
                                    height: 54,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [primary, primaryViolet],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withOpacity(0.28),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'View emergency',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded,
                                            size: 19, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Recent IDs — tap to reuse instead of retyping
                                if (_recentIds.isNotEmpty)
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Icon(Icons.history_rounded,
                                          size: 14, color: textMuted),
                                      ..._recentIds.map(
                                        (id) => GestureDetector(
                                          onTap: () => _selectRecent(id),
                                          child: Text(
                                            id,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: primary.withOpacity(0.85),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 12, color: textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Authorized responders only',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandMark() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withOpacity(0.22),
            const Color(0xFF17243D).withOpacity(0.55),
          ],
        ),
        border: Border.all(color: primary.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
              color: primary.withOpacity(0.10), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 40, color: primary),
          const Icon(Icons.monitor_heart_outlined,
              size: 16, color: Colors.white),
        ],
      ),
    );
  }
}
