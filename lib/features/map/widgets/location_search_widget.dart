import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/location_model.dart';
import '../providers/location_provider.dart';

class LocationSearchWidget extends ConsumerStatefulWidget {
  final String label;
  final Function(LocationModel) onSelected;
  final TextEditingController? controller;
  final IconData? icon;
  final Color? iconColor;

  const LocationSearchWidget({
    super.key,
    required this.label,
    required this.onSelected,
    this.controller,
    this.icon,
    this.iconColor,
  });

  @override
  ConsumerState<LocationSearchWidget> createState() =>
      _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends ConsumerState<LocationSearchWidget> {
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  CancelToken? _cancelToken;

  List<LocationModel> _predictions = [];
  bool _isLoading = false;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _textController.removeListener(_onTextChanged);
    if (widget.controller == null) {
      _textController.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (_textController.text.trim().isNotEmpty && _predictions.isNotEmpty) {
        _showOverlay();
      }
    } else {
      // Delay removing overlay slightly so onTap on recommendation items registers first
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    final text = _textController.text.trim();
    if (!_focusNode.hasFocus) return;

    _debounceTimer?.cancel();
    _cancelToken?.cancel();

    if (text.length < 2) {
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final cancelToken = CancelToken();
      _cancelToken = cancelToken;

      try {
        final results = await ref
            .read(locationRepositoryProvider)
            .search(text, cancelToken: cancelToken);

        if (!mounted) return;

        setState(() {
          _predictions = results;
          _isLoading = false;
        });

        if (_predictions.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) return;
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    final overlayState = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: Material(
              elevation: 12,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: _predictions.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: isDark ? Colors.white12 : const Color(0xFFEDF2F7),
                      indent: 52,
                    ),
                    itemBuilder: (context, index) {
                      final item = _predictions[index];
                      final mainText = item.name;
                      String secondaryText = item.secondaryAddress ?? '';

                      if (secondaryText.isEmpty &&
                          item.fullAddress.isNotEmpty) {
                        if (item.fullAddress != mainText) {
                          if (item.fullAddress.startsWith(mainText)) {
                            secondaryText = item.fullAddress
                                .substring(mainText.length)
                                .replaceFirst(RegExp(r'^,\s*'), '');
                          } else {
                            secondaryText = item.fullAddress;
                          }
                        }
                      }

                      return InkWell(
                        onTap: () => _handleSelection(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      (widget.iconColor ??
                                              const Color(0xFF14D8C4))
                                          .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color:
                                      widget.iconColor ??
                                      const Color(0xFF14D8C4),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      mainText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (secondaryText.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        secondaryText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          color: isDark
                                              ? Colors.white54
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isDetecting = true);
    try {
      final position = await ref
          .read(locationServiceProvider)
          .determinePosition();

      if (position == null) {
        throw Exception("Could not retrieve current location");
      }

      ref.read(locationServiceProvider).updateCurrentPosition(position);

      final address = await ref
          .read(locationRepositoryProvider)
          .reverseGeocode(position.latitude, position.longitude);

      final String exactAddress = (address != null && address.trim().isNotEmpty)
          ? address.trim()
          : "My Current Location";

      if (mounted) {
        final loc = LocationModel(
          id: 'current_${DateTime.now().millisecondsSinceEpoch}',
          name: exactAddress,
          fullAddress: exactAddress,
          secondaryAddress: exactAddress,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _handleSelection(loc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  void _handleSelection(LocationModel selection) async {
    _removeOverlay();

    setState(() => _isLoading = true);
    final detailedLocation = await ref
        .read(locationRepositoryProvider)
        .getDetails(selection);

    if (!mounted) return;
    setState(() => _isLoading = false);

    _textController.text = detailedLocation.name;
    FocusScope.of(context).unfocus();
    await ref.read(locationRepositoryProvider).saveToRecents(detailedLocation);
    widget.onSelected(detailedLocation);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFECECEC),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (widget.iconColor ?? const Color(0xFF14D8C4)).withValues(
                  alpha: 0.1,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon ?? Icons.search_rounded,
                color: widget.iconColor ?? const Color(0xFF14D8C4),
                size: 20,
              ),
            ),
            suffixIcon: _isLoading
                ? Container(
                    padding: const EdgeInsets.all(18),
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF14D8C4),
                      ),
                    ),
                  )
                : IconButton(
                    icon: _isDetecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF14D8C4),
                            ),
                          )
                        : Icon(
                            Icons.my_location_rounded,
                            color: widget.iconColor ?? const Color(0xFF14D8C4),
                            size: 20,
                          ),
                    onPressed: _isDetecting ? null : _useCurrentLocation,
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      ),
    );
  }
}
