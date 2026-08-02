import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

void main() {
  runApp(const PlayBoxTV());
}

class PlayBoxTV extends StatelessWidget {
  const PlayBoxTV({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayBoxTV',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE94560),
        scaffoldBackgroundColor: const Color(0xFF0A0A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A3E),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const DekoderPlayBoxTV(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DekoderPlayBoxTV extends StatefulWidget {
  const DekoderPlayBoxTV({super.key});

  @override
  State<DekoderPlayBoxTV> createState() => _DekoderPlayBoxTVState();
}

class _DekoderPlayBoxTVState extends State<DekoderPlayBoxTV> {
  List<Map<String, String>> kanaly = [];
  List<Map<String, String>> filtrowaneKanaly = [];
  VideoPlayerController? controller;
  TextEditingController urlController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  bool isLoading = false;
  String status = '📺 PlayBoxTV - Gotowy. Wklej link do listy M3U.';
  bool isPlaying = false;
  int? aktualnyIndex;

  final String defaultM3U = 
      'https://raw.githubusercontent.com/iptv-org/iptv/master/streams/pl.m3u';

  @override
  void initState() {
    super.initState();
    urlController.text = defaultM3U;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pobierzListe();
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    urlController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> pobierzListe() async {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        status = '❌ Wprowadź adres listy M3U!';
      });
      return;
    }

    setState(() {
      isLoading = true;
      status = '⏳ Pobieranie listy kanałów...';
    });

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': '*/*',
        },
      );

      if (response.statusCode == 200) {
        parsujM3U(response.body);
        setState(() {
          status = '✅ PlayBoxTV - Załadowano ${kanaly.length} kanałów';
          isLoading = false;
        });
      } else {
        setState(() {
          status = '❌ Błąd HTTP: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        status = '❌ Błąd: $e';
        isLoading = false;
      });
    }
  }

  void parsujM3U(String zawartosc) {
    List<Map<String, String>> noweKanaly = [];
    List<String> linie = zawartosc.split('\n');
    String nazwa = '';
    String link = '';

    for (String line in linie) {
      line = line.trim();
      
      if (line.startsWith('#EXTINF:')) {
        int commaIndex = line.indexOf(',');
        if (commaIndex != -1) {
          nazwa = line.substring(commaIndex + 1).trim();
          nazwa = nazwa.replaceAll(RegExp(r'\[.*?\]'), '').trim();
          nazwa = nazwa.replaceAll(RegExp(r'\(.*?\)'), '').trim();
        } else {
          nazwa = 'Nieznany';
        }
      } else if (line.isNotEmpty && 
                 !line.startsWith('#') && 
                 (line.startsWith('http://') || line.startsWith('https://'))) {
        link = line;
        if (nazwa.isNotEmpty && link.isNotEmpty) {
          noweKanaly.add({'nazwa': nazwa, 'link': link});
          nazwa = '';
          link = '';
        }
      }
    }

    if (nazwa.isNotEmpty && link.isNotEmpty) {
      noweKanaly.add({'nazwa': nazwa, 'link': link});
    }

    setState(() {
      kanaly = noweKanaly;
      filtrowaneKanaly = List.from(kanaly);
    });
  }

  void filtrujKanaly(String tekst) {
    setState(() {
      if (tekst.isEmpty) {
        filtrowaneKanaly = List.from(kanaly);
      } else {
        filtrowaneKanaly = kanaly.where((kanal) =>
          kanal['nazwa']!.toLowerCase().contains(tekst.toLowerCase())
        ).toList();
      }
    });
  }

  Future<void> odtworzKanal(int index) async {
    final kanal = filtrowaneKanaly[index];
    if (kanal == null) return;

    int prawdziwyIndex = kanaly.indexOf(kanal);

    setState(() {
      aktualnyIndex = prawdziwyIndex;
      status = '🎬 Odtwarzanie: ${kanal['nazwa']}';
      isPlaying = true;
    });

    controller?.dispose();

    try {
      controller = VideoPlayerController.network(
        kanal['link']!,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://google.com',
        },
      );

      await controller!.initialize();
      await controller!.play();
      setState(() {});
    } catch (e) {
      setState(() {
        status = '⚠️ Błąd odtwarzania: $e';
        isPlaying = false;
      });
    }
  }

  void zatrzymaj() {
    controller?.pause();
    controller?.dispose();
    controller = null;
    setState(() {
      isPlaying = false;
      status = '⏹ Zatrzymano';
      aktualnyIndex = null;
    });
  }

  void udostepnij() {
    if (aktualnyIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw wybierz kanał!')),
      );
      return;
    }
    final kanal = kanaly[aktualnyIndex!];
    Share.share('📺 PlayBoxTV - ${kanal['nazwa']}\n${kanal['link']}');
  }

  Widget buildChannelList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }

    if (filtrowaneKanaly.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off, size: 60, color: Colors.grey[600]),
            const SizedBox(height: 10),
            Text(
              'Brak kanałów',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              'Kliknij "📡 Pobierz" aby załadować listę',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtrowaneKanaly.length,
      itemBuilder: (context, index) {
        final kanal = filtrowaneKanaly[index];
        final bool isActive = kanaly.indexOf(kanal) == aktualnyIndex;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: isActive ? const Color(0xFFE94560).withOpacity(0.2) : Colors.transparent,
          child: ListTile(
            leading: isActive 
                ? const Icon(Icons.play_circle, color: Color(0xFFE94560))
                : const Icon(Icons.tv, color: Colors.grey),
            title: Text(
              kanal['nazwa']!,
              style: TextStyle(
                color: isActive ? const Color(0xFFE94560) : Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isActive 
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () => odtworzKanal(index),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv, color: Color(0xFFE94560), size: 20),
            const SizedBox(width: 8),
            const Text(
              'PlayBoxTV',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE94560).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${filtrowaneKanaly.length}/${kanaly.length}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFFE94560)),
            onPressed: udostepnij,
            tooltip: 'Udostępnij kanał',
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF1A1A3E),
            onSelected: (value) {
              urlController.text = value;
              pobierzListe();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'https://raw.githubusercontent.com/iptv-org/iptv/master/streams/pl.m3u',
                child: Text('🇵🇱 Polskie kanały'),
              ),
              const PopupMenuItem(
                value: 'https://iptv-org.github.io/iptv/index.m3u',
                child: Text('🌍 Wszystkie kanały'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Wklej link do listy M3U...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1A1A3E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE94560), width: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: pobierzListe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94560),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('📡 Pobierz'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE94560).withOpacity(0.3), width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: status.contains('❌') ? Colors.red :
                               status.contains('✅') ? Colors.green :
                               status.contains('⚠️') ? Colors.orange :
                               const Color(0xFFE94560),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (isPlaying)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (controller != null && controller!.value.isInitialized)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE94560).withOpacity(0.3)),
                ),
                child: VideoPlayer(controller!),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A3E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE94560).withOpacity(0.2)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.tv, size: 50, color: Color(0xFFE94560)),
                      const SizedBox(height: 8),
                      Text(
                        'PlayBoxTV',
                        style: TextStyle(
                          color: const Color(0xFFE94560),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Wybierz kanał z listy',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (controller != null && controller!.value.isInitialized)
                  IconButton(
                    icon: Icon(
                      controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFFE94560),
                      size: 30,
                    ),
                    onPressed: () {
                      setState(() {
                        if (controller!.value.isPlaying) {
                          controller!.pause();
                        } else {
                          controller!.play();
                        }
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Color(0xFFE94560), size: 30),
                  onPressed: zatrzymaj,
                ),
                const SizedBox(width: 16),
                Text(
                  isPlaying ? '🔴 NA ŻYWO' : '⏹ ZATRZYMANY',
                  style: TextStyle(
                    color: isPlaying ? Colors.red : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE94560).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PlayBoxTV',
                    style: TextStyle(
                      color: Color(0xFFE94560),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: filtrujKanaly,
              decoration: InputDecoration(
                hintText: '🔍 Szukaj kanału...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1A1A3E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE94560), width: 0.5),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffix: Text(
                  '${filtrowaneKanaly.length}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A3E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE94560).withOpacity(0.2)),
                ),
                child: buildChannelList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}