import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/file_info.dart';

class VideoPlayerPage extends StatefulWidget {
  final String url;
  final List<FileInfo> videoList;
  final int currentIndex;

  const VideoPlayerPage({
    super.key,
    required this.url,
    required this.videoList,
    required this.currentIndex,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late int _currentIndex;
  bool _showPlaylist = false;
  List<AudioTrack> _audioTracks = [];
  bool _isInitialized = false;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _player = Player();
    _controller = VideoController(_player);
    _initListeners();
    _openVideo(widget.url);
  }

  void _initListeners() {
    _subscriptions.add(
      _player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        final audioTracks =
            tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
        setState(() => _audioTracks = audioTracks);
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed && mounted) {
          _playNext();
        }
      }),
    );
  }

  Future<void> _openVideo(String url) async {
    setState(() {
      _isInitialized = false;
      _audioTracks = [];
    });
    try {
      await _player.open(Media(url));
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialized = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频加载失败: $e')),
        );
      }
    }
  }

  void _selectVideo(int index) {
    if (index != _currentIndex &&
        index >= 0 &&
        index < widget.videoList.length) {
      setState(() {
        _currentIndex = index;
        _showPlaylist = false;
      });
      _openVideo(widget.videoList[index].url ?? '');
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _selectVideo(_currentIndex - 1);
    }
  }

  void _playNext() {
    if (_currentIndex < widget.videoList.length - 1) {
      _selectVideo(_currentIndex + 1);
    }
  }

  void _showAudioTrackSelector() {
    if (_audioTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前视频没有可切换的音轨')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a2a),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '音轨选择',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy, color: Colors.white70),
              title: const Text('自动', style: TextStyle(color: Colors.white)),
              onTap: () {
                _player.setAudioTrack(AudioTrack.auto());
                Navigator.pop(context);
              },
            ),
            ..._audioTracks.map((track) {
              final parts = <String>[];
              if (track.title != null && track.title!.isNotEmpty) {
                parts.add(track.title!);
              }
              if (track.language != null && track.language!.isNotEmpty) {
                parts.add(track.language!);
              }
              if (parts.isEmpty) {
                parts.add('音轨 ${track.id}');
              }
              final label = parts.join(' · ');
              return ListTile(
                leading: const Icon(Icons.audiotrack, color: Colors.white70),
                title:
                    Text(label, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  _player.setAudioTrack(track);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.videoList.isNotEmpty
              ? widget.videoList[_currentIndex].name
              : '视频播放',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_audioTracks.length > 1)
            IconButton(
              icon: const Icon(Icons.audio_file),
              onPressed: _showAudioTrackSelector,
              tooltip: '音轨选择',
            ),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () =>
                setState(() => _showPlaylist = !_showPlaylist),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _isInitialized
                    ? MaterialVideoControlsTheme(
                        normal: MaterialVideoControlsThemeData(
                          padding: const EdgeInsets.only(bottom: 24),
                        ),
                        fullscreen: MaterialVideoControlsThemeData(
                          padding: const EdgeInsets.only(bottom: 24),
                        ),
                        child: Video(controller: _controller),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                if (_showPlaylist) _buildPlaylist(),
              ],
            ),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final hasPrevious = _currentIndex > 0;
    final hasNext = _currentIndex < widget.videoList.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF2a2a2a),
        border: Border(
          top: BorderSide(color: Colors.white24, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.skip_previous,
              color: hasPrevious ? Colors.white : Colors.white30,
            ),
            onPressed: hasPrevious ? _playPrevious : null,
            tooltip: '上一个',
            iconSize: 28,
          ),
          const SizedBox(width: 24),
          IconButton(
            icon: Icon(
              Icons.skip_next,
              color: hasNext ? Colors.white : Colors.white30,
            ),
            onPressed: hasNext ? _playNext : null,
            tooltip: '下一个',
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist() {
    return GestureDetector(
      onTap: () => setState(() => _showPlaylist = false),
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF2a2a2a),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '播放列表 (${widget.videoList.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () =>
                              setState(() => _showPlaylist = false),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.videoList.length,
                      itemBuilder: (context, index) {
                        final video = widget.videoList[index];
                        final isActive = index == _currentIndex;

                        return ListTile(
                          leading: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey,
                            ),
                          ),
                          title: Text(
                            video.name,
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : Colors.grey[300],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isActive
                              ? const Icon(Icons.play_arrow,
                                  color: Colors.green, size: 20)
                              : null,
                          shape: isActive
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          tileColor:
                              isActive ? Colors.green.withValues(alpha: 0.3) : null,
                          onTap: () => _selectVideo(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
