import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  final List<Map<String, String>> _tracks = List.generate(10, (i) {
    return {
      'title': '음악 ${i + 1}',
      'asset': 'assets/audio/lullaby${(i % 3) + 1}.mp3',
      'cover': 'assets/images/cover${(i % 3) + 1}.jpg',
    };
  });

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _setAudioSource(_currentIndex);
  }

  Future<void> _setAudioSource(int index) async {
    try {
      await _player.setAsset(_tracks[index]['asset']!);
    } catch (_) {}
    setState(() => _currentIndex = index);
  }

  void _playNext() {
    final next = (_currentIndex + 1) % _tracks.length;
    _setAudioSource(next);
    _player.play();
  }

  void _playPrevious() {
    final prev = (_currentIndex - 1 + _tracks.length) % _tracks.length;
    _setAudioSource(prev);
    _player.play();
  }

  void _toggleLoopMode() {
    setState(() {
      if (_loopMode == LoopMode.off) {
        _loopMode = LoopMode.all;
      } else if (_loopMode == LoopMode.all) {
        _loopMode = LoopMode.one;
      } else {
        _loopMode = LoopMode.off;
      }
      _player.setLoopMode(_loopMode);
    });
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
      _player.setShuffleModeEnabled(_isShuffle);
    });
  }

  void _showExpandedPlayer() {
    final currentTrack = _tracks[_currentIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              top: 24,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, color: Colors.grey.shade300),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    currentTrack['cover']!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  currentTrack['title']!,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = _player.duration ?? const Duration(seconds: 1);
                    return Column(
                      children: [
                        Slider(
                          value: position.inSeconds.toDouble(),
                          max: total.inSeconds.toDouble(),
                          onChanged: (value) => _player.seek(Duration(seconds: value.toInt())),
                          activeColor: Colors.deepPurple,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            Text(_formatDuration(total)),
                          ],
                        )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: Icon(Icons.shuffle,
                          color: _isShuffle ? Colors.deepPurple : Colors.grey),
                      onPressed: _toggleShuffle,
                    ),
                    IconButton(icon: const Icon(Icons.skip_previous), onPressed: _playPrevious),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing ?? false;
                        return IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          iconSize: 36,
                          onPressed: () => isPlaying ? _player.pause() : _player.play(),
                        );
                      },
                    ),
                    IconButton(icon: const Icon(Icons.skip_next), onPressed: _playNext),
                    IconButton(
                      icon: Icon(
                        _loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                        color: _loopMode != LoopMode.off ? Colors.deepPurple : Colors.grey,
                      ),
                      onPressed: _toggleLoopMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = _tracks[_currentIndex];

    return Scaffold(

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      _tracks[index]['cover']!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(_tracks[index]['title']!),
                  trailing: index == _currentIndex
                      ? const Icon(Icons.play_arrow)
                      : null,
                  onTap: () async {
                    await _setAudioSource(index);
                    _player.play();
                  },
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: InkWell(
              onTap: _showExpandedPlayer,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  border: Border(top: BorderSide(color: Colors.deepPurple.shade100)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        currentTrack['cover']!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentTrack['title']!,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing ?? false;
                        return IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.deepPurple),
                          onPressed: () => isPlaying ? _player.pause() : _player.play(),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.deepPurple),
                      onPressed: _playNext,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
