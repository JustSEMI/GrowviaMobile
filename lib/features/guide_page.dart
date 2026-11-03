import 'package:flutter/material.dart';

import '../ui/components.dart';
import '../ui/growvia_icon.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  static const topics = <(String, String, String)>[
    (
      'Suhu dan ventilasi',
      'thermometer',
      'Suhu memengaruhi pertumbuhan dan kebutuhan air tanaman. Angka target pada halaman iklim adalah pengaturan ruang kerja, bukan patokan untuk semua tanaman.\n\nJika rumah kaca terasa terlalu panas, periksa ventilasi dan naungan. Sesuaikan tindakan dengan jenis tanaman serta kondisi setempat.',
    ),
    (
      'Kelembapan udara',
      'drop',
      'Udara terlalu lembap dalam waktu lama dapat mendukung pertumbuhan jamur. Sirkulasi udara dan jarak tanam membantu mengurangi kelembapan yang terperangkap.\n\nPerhatikan kondisi daun dan media tanam, bukan hanya satu angka sensor.',
    ),
    (
      'Kapan perlu menyiram?',
      'leaf',
      'Kebutuhan air bergantung pada media tanam, cuaca, dan jenis tanaman. Bacaan kelembapan tanah perlu dikalibrasi agar dapat dipahami dengan benar.\n\nHindari genangan dan periksa drainase. Ambang penyiraman ada pada halaman tanah dan air; otomasi perangkat belum aktif.',
    ),
    (
      'Cahaya dan CO2',
      'sun',
      'Cahaya dan karbon dioksida berperan dalam fotosintesis. Kebutuhannya berbeda menurut tanaman dan tahap pertumbuhan.\n\nAngka cahaya nol pada siang hari dapat menjadi alasan untuk memeriksa posisi sensor. Jangan mengubah sistem pengayaan CO2 tanpa prosedur keselamatan yang sesuai.',
    ),
    (
      'Tandon dan pompa',
      'drop',
      'Periksa ketinggian air, sambungan selang, dan kebersihan tandon secara berkala. Pompa tidak boleh dibiarkan bekerja tanpa persediaan air yang memadai.\n\nBatas ketinggian air dan durasi di ruang kerja masih berupa konfigurasi. Jangan mengandalkan pengaman otomatis sebelum integrasi perangkat diuji.',
    ),
    (
      'Kapan menghubungi admin?',
      'info',
      'Hubungi admin jika sensor atau kabel rusak, tandon bocor, selang tersumbat, atau pompa bermasalah. Diskusikan penyesuaian target untuk tanaman yang berbeda.\n\nData terakhir bukan data realtime. Periksa waktu pembacaan sebelum mengambil keputusan, dan hindari membongkar perangkat tanpa pendampingan.',
    ),
  ];

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageIntro(
        eyebrow: 'Growvia / Edukasi',
        title: 'Kenali kebunmu',
        description: 'Sedikit paham, lebih terawat. Panduan yang sama dengan website, sekarang di genggaman.',
      ),
      const SizedBox(height: 24),
      Panel(
        padding: 4,
        child: Column(
          children: [
            for (var index = 0; index < topics.length; index++) ...[
              if (index > 0) const Divider(indent: 16, endIndent: 16),
              ExpansionTile(
                key: PageStorageKey('guide-$index'),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                shape: const Border(),
                collapsedShape: const Border(),
                leading: ExcludeSemantics(
                  child: GrowviaIcon(
                    topics[index].$2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  topics[index].$1,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  Text(
                    topics[index].$3,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Notice(
        title: 'Belajar dari kebun',
        message: 'Panduan ini melengkapi pengamatan langsung. Sesuaikan perawatan dengan kebutuhan tanaman. Konfigurasi aplikasi belum diterapkan ke perangkat.',
      ),
    ],
  );
}
