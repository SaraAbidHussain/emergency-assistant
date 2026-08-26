import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Models ──────────────────────────────────────────────────────

class TimelineEvent {
  final String timestamp;
  final String title;
  final EventKind kind;

  const TimelineEvent({
    required this.timestamp,
    required this.title,
    required this.kind,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      timestamp: json['timestamp'] as String,
      title: json['event'] as String,
      kind: _kindFromTitle(json['event'] as String),
    );
  }

  static EventKind _kindFromTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('unresponsive') || lower.contains('critical')) {
      return EventKind.critical;
    }
    if (lower.contains('created') || lower.contains('reported')) {
      return EventKind.created;
    }
    if (lower.contains('vitals') || lower.contains('warning')) {
      return EventKind.warning;
    }
    return EventKind.update;
  }
}

enum EventKind { critical, warning, created, update }

class EmergencyStatus {
  final bool active;
  final int severity;
  final String type;
  final String status;
  final double lat;
  final double lng;
  final String locationLabel;
  final String summary;
  final List<TimelineEvent> timeline;

  const EmergencyStatus({
    required this.active,
    required this.severity,
    required this.type,
    required this.status,
    required this.lat,
    required this.lng,
    required this.locationLabel,
    required this.summary,
    required this.timeline,
  });

  factory EmergencyStatus.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    final rawTimeline = json['timeline'] as List<dynamic>? ?? [];
    return EmergencyStatus(
      active: json['active'] as bool? ?? false,
      severity: json['severity'] as int? ?? 1,
      type: json['type'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'responding',
      lat: (loc['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (loc['lng'] as num?)?.toDouble() ?? 0.0,
      locationLabel: json['location_label'] as String? ?? 'Unknown location',
      summary: json['summary'] as String? ?? '',
      timeline: rawTimeline
          .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Mock API service ───────────────────────────────────────────
// Swap getStatus() for a real http/dio call to
// GET /emergency/{user_id}/status once the backend is live —
// everything downstream reads from this one method.

class ApiService {
  static Future<EmergencyStatus> getStatus(String emergencyId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    return EmergencyStatus.fromJson({
      'active': true,
      'severity': 4,
      'type': 'injury',
      'status': 'unresponsive',
      'location': {'lat': 33.6844, 'lng': 73.0479},
      'location_label': 'Riverfront Park, Central City',
      'summary':
          'Patient found unconscious after a fall from height. Possible '
              'head and back injuries. No response to verbal stimuli. '
              'Immediate medical attention required.',
      'timeline': [
        {'timestamp': '10:24 AM', 'event': 'Marked unresponsive'},
        {'timestamp': '10:20 AM', 'event': 'Vitals unstable'},
        {'timestamp': '10:18 AM', 'event': 'Responder team on scene'},
        {'timestamp': '10:15 AM', 'event': 'Emergency created'},
      ],
    });
  }
}

// ── Palette ─────────────────────────────────────────────────────

class _Palette {
  static const background = Color(0xFF05070A);
  static const surface = Color(0xFF10151D);
  static const critical = Color(0xFFE24B4A);
  static const warning = Color(0xFFE89A5C);
  static const success = Color(0xFF52D49A);
  static const violet = Color(0xFF7B6EFF);
  static const accent = Color(0xFF7FA3FF);
  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFF8993A3);
  static const textMuted = Color(0xFF5D6675);

  static Color severityColor(int severity) {
    switch (severity) {
      case 1:
        return const Color(0xFF52D49A);
      case 2:
        return const Color(0xFFE8C85C);
      case 3:
        return const Color(0xFFE89A5C);
      case 4:
      default:
        return critical;
    }
  }

  static String severityLabel(int severity) {
    switch (severity) {
      case 1:
        return 'LOW';
      case 2:
        return 'MODERATE';
      case 3:
        return 'HIGH';
      case 4:
      default:
        return 'CRITICAL';
    }
  }
}

// ── Dashboard screen ───────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final String emergencyId;

  const DashboardScreen({super.key, required this.emergencyId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _LoadState { loading, loaded, error, notFound }

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;
  EmergencyStatus? _status;
  _LoadState _loadState = _LoadState.loading;
  bool _connectionLost = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fetchStatus();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchStatus(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus({bool silent = false}) async {
    if (!silent) {
      setState(() => _loadState = _LoadState.loading);
    }

    try {
      final result = await ApiService.getStatus(widget.emergencyId);

      if (!mounted) return;

      if (!result.active) {
        setState(() => _loadState = _LoadState.notFound);
        return;
      }

      setState(() {
        _status = result;
        _loadState = _LoadState.loaded;
        _connectionLost = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent && _status != null) {
        // Keep showing last-known data, just flag the banner.
        setState(() => _connectionLost = true);
      } else {
        setState(() => _loadState = _LoadState.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  height: 260,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.0,
                      colors: [
                        Color(0x38E24B4A),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _buildTopBar(),
                if (_connectionLost) _buildConnectionBanner(),
                Expanded(child: _buildBody()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 16, color: _Palette.textSecondary),
            ),
          ),
          Text(
            widget.emergencyId,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: _Palette.textMuted,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final isLive =
                      _loadState == _LoadState.loaded && !_connectionLost;
                  final glow = isLive ? _pulseController.value : 0.0;
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLive ? _Palette.success : _Palette.textMuted,
                      boxShadow: isLive
                          ? [
                              BoxShadow(
                                color: _Palette.success
                                    .withOpacity(0.6 * glow + 0.2),
                                blurRadius: 8,
                              ),
                            ]
                          : [],
                    ),
                  );
                },
              ),
              const SizedBox(width: 5),
              Text(
                _connectionLost ? 'OFFLINE' : 'LIVE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _connectionLost
                      ? _Palette.textMuted
                      : _Palette.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _Palette.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 13, color: _Palette.warning),
          const SizedBox(width: 8),
          Text(
            'Connection lost — retrying…',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: _Palette.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Body / states ───────────────────────────────────────────

  Widget _buildBody() {
    switch (_loadState) {
      case _LoadState.loading:
        return _buildLoading();
      case _LoadState.error:
        return _buildErrorState(
          'Something went wrong',
          "Couldn't load this emergency. Check your connection and try again.",
        );
      case _LoadState.notFound:
        return _buildErrorState(
          'No active emergency',
          'There\'s no active emergency for ID ${widget.emergencyId}.',
        );
      case _LoadState.loaded:
        return _buildLoaded(_status!);
    }
  }

  Widget _buildLoading() {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(_Palette.accent),
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: _Palette.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _Palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: _Palette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _fetchStatus(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Palette.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(EmergencyStatus status) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _SeverityHero(
            severity: status.severity,
            type: status.type,
            status: status.status,
            pulse: _pulseController,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _LocationCard(
            lat: status.lat,
            lng: status.lng,
            label: status.locationLabel,
            pulse: _pulseController,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _SummaryCard(summary: status.summary),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _TimelineList(events: status.timeline),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: _ActionRow(
            onCall: () => HapticFeedback.lightImpact(),
            onDispatch: () => HapticFeedback.mediumImpact(),
          ),
        ),
      ],
    );
  }
}

// ── Severity hero card ─────────────────────────────────────────

class _SeverityHero extends StatelessWidget {
  final int severity;
  final String type;
  final String status;
  final Animation<double> pulse;

  const _SeverityHero({
    required this.severity,
    required this.type,
    required this.status,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final color = _Palette.severityColor(severity);
    final isCritical = severity == 4;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.22), _Palette.background],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEVERITY LEVEL',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: color.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$severity',
                        style: GoogleFonts.inter(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _Palette.severityLabel(severity),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _Palette.background,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: pulse,
                builder: (context, child) {
                  final scale = isCritical ? 1.0 + (pulse.value * 0.08) : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.4), width: 3),
                      ),
                      child: Icon(Icons.warning_rounded, size: 20, color: color),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniInfoChip(
                  icon: Icons.medical_services_outlined,
                  label: type[0].toUpperCase() + type.substring(1),
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniInfoChip(
                  icon: Icons.monitor_heart_outlined,
                  label: status[0].toUpperCase() + status.substring(1),
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _Palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location card ───────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final double lat;
  final double lng;
  final String label;
  final Animation<double> pulse;

  const _LocationCard({
    required this.lat,
    required this.lng,
    required this.label,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                // TODO: replace with a real GoogleMap/FlutterMap widget
                // centered on (lat, lng) once the maps API key is wired in.
                Positioned.fill(
                  child: CustomPaint(painter: _GridPainter()),
                ),
                Center(
                  child: AnimatedBuilder(
                    animation: pulse,
                    builder: (context, child) {
                      return Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _Palette.critical,
                          boxShadow: [
                            BoxShadow(
                              color: _Palette.critical
                                  .withOpacity(0.35 * pulse.value + 0.1),
                              blurRadius: 20,
                              spreadRadius: 8 * pulse.value,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation_rounded,
                            size: 12, color: _Palette.accent),
                        const SizedBox(width: 5),
                        Text(
                          'Directions',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _Palette.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _Palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: _Palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: _Palette.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0E1712);
    canvas.drawRect(Offset.zero & size, bg);

    final line = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── AI summary card ──────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.violet.withOpacity(0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _Palette.violet.withOpacity(0.12),
            _Palette.violet.withOpacity(0.03),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: Color(0xFFB3A9F5)),
              const SizedBox(width: 6),
              Text(
                'AI SUMMARY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: const Color(0xFFB3A9F5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.55,
              color: const Color(0xFFD8DAE0),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────

class _TimelineList extends StatelessWidget {
  final List<TimelineEvent> events;

  const _TimelineList({required this.events});

  Color _colorFor(EventKind kind) {
    switch (kind) {
      case EventKind.critical:
        return _Palette.critical;
      case EventKind.warning:
        return _Palette.warning;
      case EventKind.created:
        return _Palette.success;
      case EventKind.update:
        return _Palette.accent;
    }
  }

  IconData _iconFor(EventKind kind) {
    switch (kind) {
      case EventKind.critical:
        return Icons.error_outline_rounded;
      case EventKind.warning:
        return Icons.warning_amber_rounded;
      case EventKind.created:
        return Icons.flag_outlined;
      case EventKind.update:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIMELINE',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _Palette.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            color: _colorFor(events[i].kind),
            icon: _iconFor(events[i].kind),
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineEvent event;
  final Color color;
  final IconData icon;
  final bool isLast;

  const _TimelineRow({
    required this.event,
    required this.color,
    required this.icon,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: const Color(0xFF252B34),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.timestamp,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _Palette.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onDispatch;

  const _ActionRow({required this.onCall, required this.onDispatch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onCall,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.call_outlined,
                      size: 16, color: _Palette.textPrimary),
                  const SizedBox(width: 7),
                  Text(
                    'Call caller',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _Palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 13,
          child: GestureDetector(
            onTap: onDispatch,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [_Palette.critical, Color(0xFFC13A3A)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _Palette.critical.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flag_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    'Dispatch team',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
