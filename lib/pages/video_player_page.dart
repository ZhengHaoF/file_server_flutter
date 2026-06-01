import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
  late int _currentIndex;
  late String _currentUrl;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _showPlaylist = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _currentUrl = widget.url;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    setState(() => _isInitialized = false);

    _videoController?.dispose();
    _chewieController?.dispose();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(_currentUrl));

    try {
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.green,
          handleColor: Colors.greenAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _isInitialized = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频加载失败: $e')),
        );
      }
    }
  }

  void _selectVideo(int index) {
    if (index != _currentIndex && index >= 0 && index < widget.videoList.length) {
      setState(() {
        _currentIndex = index;
        _currentUrl = widget.videoList[index].url ?? '';
        _showPlaylist = false;
      });
      _initPlayer();
    }
  }

  void _playNext() {
    if (_currentIndex < widget.videoList.length - 1) {
      _selectVideo(_currentIndex + 1);
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _selectVideo(_currentIndex - 1);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
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
          widget.videoList.isNotEmpty ? widget.videoList[_currentIndex].name : '视频播放',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () {
              setState(() => _showPlaylist = !_showPlaylist);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isInitialized && _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
              _buildControls(),
            ],
          ),
          if (_showPlaylist) _buildPlaylist(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            onPressed: _currentIndex > 0 ? _playPrevious : null,
          ),
          const SizedBox(width: 32),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white),
            onPressed: _currentIndex < widget.videoList.length - 1 ? _playNext : null,
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                          onPressed: () => setState(() => _showPlaylist = false),
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
                              color: isActive ? Colors.white : Colors.grey[300],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isActive
                              ? const Icon(Icons.play_arrow, color: Colors.green, size: 20)
                              : null,
                          tileColor: isActive ? Colors.green.withOpacity(0.3) : null,
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
