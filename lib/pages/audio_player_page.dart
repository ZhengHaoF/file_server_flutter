import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerPage extends StatefulWidget {
  final String url;

  const AudioPlayerPage({super.key, required this.url});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  late AudioPlayer _player;
  final List<StreamSubscription> _subscriptions = [];
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      }),
    );
    _subscriptions.add(
      _player.positionStream.listen((position) {
        if (mounted) setState(() => _position = position);
      }),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          // 播放完成处理
          if (state.processingState == ProcessingState.completed) {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
        }
      }),
    );

    await _player.setUrl(widget.url);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音频播放'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),
              Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble() > 0
                    ? _duration.inSeconds.toDouble()
                    : 1,
                onChanged: (value) {
                  _player.seek(Duration(seconds: value.toInt()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position)),
                    Text(_formatDuration(_duration)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () async {
                      if (_isPlaying) {
                        await _player.pause();
                      } else {
                        await _player.play();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
