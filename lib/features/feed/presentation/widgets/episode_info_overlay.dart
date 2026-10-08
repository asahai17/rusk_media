import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/episode_entity.dart';

class EpisodeInfoOverlay extends StatelessWidget {
  final EpisodeEntity episode;
  final bool isLiked;
  final int likeCount;
  final bool isMuted;
  final double bottomPadding;
  final VoidCallback onLikeTap;
  final VoidCallback onMuteTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;

  const EpisodeInfoOverlay({
    super.key,
    required this.episode,
    required this.isLiked,
    required this.likeCount,
    required this.isMuted,
    required this.bottomPadding,
    required this.onLikeTap,
    required this.onMuteTap,
    required this.onCommentTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final effectiveBottom = bottomPadding + 60;

    return Stack(
      children: [
        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Brand with ambient glow for readability
                _BrandLogo(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${episode.id.toString().padLeft(2, '0')} / ${AppConstants.totalEpisodes.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right-side action column
        Positioned(
          right: 12,
          bottom: effectiveBottom + 8,
          child: _ActionColumn(
            isLiked: isLiked,
            likeCount: likeCount,
            isMuted: isMuted,
            onLikeTap: onLikeTap,
            onCommentTap: onCommentTap,
            onShareTap: onShareTap,
            onMuteTap: onMuteTap,
          ),
        ),

        // Bottom info area
        Positioned(
          left: 0,
          right: 72,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(14, 50, 8, effectiveBottom),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
                stops: [0.0, 1.0],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'EP ${episode.id}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  episode.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.2,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  episode.description,
                  style: const TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 12,
                    height: 1.4,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionColumn extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final bool isMuted;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onMuteTap;

  const _ActionColumn({
    required this.isLiked,
    required this.likeCount,
    required this.isMuted,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onMuteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedActionButton(
          icon:
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: _formatCount(likeCount),
          color: isLiked ? AppColors.heartRed : Colors.white,
          onTap: onLikeTap,
          animate: isLiked,
        ),
        const SizedBox(height: 22),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: '2.3K',
          color: Colors.white,
          onTap: onCommentTap,
        ),
        const SizedBox(height: 22),
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          color: Colors.white,
          onTap: onShareTap,
        ),
        const SizedBox(height: 22),
        _MuteButton(isMuted: isMuted, onTap: onMuteTap),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _MuteButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onTap;

  const _MuteButton({required this.isMuted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Column(
          key: ValueKey(isMuted),
          children: [
            Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 3),
            Text(
              isMuted ? 'Muted' : 'Sound',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool animate;

  const _AnimatedActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.animate,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(_AnimatedActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _scaleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  double _scaleValue(double t) {
    if (t < 0.4) {
      return 1.0 + 0.3 * Curves.easeOut.transform(t / 0.4);
    } else {
      return 1.3 - 0.3 * Curves.easeInOut.transform((t - 0.4) / 0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use GestureDetector with opaque behavior — NO splash/ripple/grey container
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _scaleController.forward(from: 0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleValue(_scaleController.value),
            child: child,
          );
        },
        child: Column(
          children: [
            Icon(widget.icon, color: widget.color, size: 28),
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand logo with ambient glow shader effect for readability on any background.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ambient glow behind text
        Positioned(
          left: -8,
          top: -4,
          right: -8,
          bottom: -4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(50),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        // "MD" in white bold + "Television" in primary
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'MD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(color: Color(0xCC000000), blurRadius: 12),
                  Shadow(color: Color(0x66E63946), blurRadius: 20),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Television',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(color: Colors.black.withAlpha(200), blurRadius: 12),
                  Shadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
